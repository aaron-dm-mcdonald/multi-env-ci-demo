package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	awsconfig "github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/ec2"
	ec2types "github.com/aws/aws-sdk-go-v2/service/ec2/types"
)

type MetadataResponse struct {
	InstanceID string            `json:"instance_id"`
	Region     string            `json:"region"`
	AZ         string            `json:"availability_zone"`
	SubnetID   string            `json:"subnet_id"`
	SubnetCIDR string            `json:"subnet_cidr"`
	VpcID      string            `json:"vpc_id"`
	VpcName    string            `json:"vpc_name"`
	InternalIP string            `json:"internal_ip"`
	Tags       map[string]string `json:"tags"`
}

func main() {
	mux := http.NewServeMux()

	mux.HandleFunc("/healthz", healthzHandler)
	mux.HandleFunc("/hello", helloHandler)
	mux.HandleFunc("/add", addHandler)
	mux.HandleFunc("/metadata", metadataHandler)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	addr := ":" + port
	log.Printf("starting api on %s", addr)

	srv := &http.Server{
		Addr:              addr,
		Handler:           loggingMiddleware(mux),
		ReadHeaderTimeout: 5 * time.Second,
	}

	log.Fatal(srv.ListenAndServe())
}

func healthzHandler(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{
		"status": "ok",
	})
}

func helloHandler(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{
		"message": "hello world",
	})
}

func addHandler(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	var a, b int

	_, err := fmt.Sscanf(q.Get("a"), "%d", &a)
	if err != nil {
		http.Error(w, "invalid parameter: a must be an integer", http.StatusBadRequest)
		return
	}

	_, err = fmt.Sscanf(q.Get("b"), "%d", &b)
	if err != nil {
		http.Error(w, "invalid parameter: b must be an integer", http.StatusBadRequest)
		return
	}

	writeJSON(w, http.StatusOK, map[string]int{
		"a":      a,
		"b":      b,
		"result": a + b,
	})
}

func metadataHandler(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 10*time.Second)
	defer cancel()

	token, err := getIMDSToken(ctx)
	if err != nil {
		http.Error(w, "failed to get IMDS token: "+err.Error(), http.StatusInternalServerError)
		return
	}

	instanceID, err := getIMDSValue(ctx, token, "/latest/meta-data/instance-id")
	if err != nil {
		http.Error(w, "failed to get instance-id: "+err.Error(), http.StatusInternalServerError)
		return
	}

	az, err := getIMDSValue(ctx, token, "/latest/meta-data/placement/availability-zone")
	if err != nil {
		http.Error(w, "failed to get availability zone: "+err.Error(), http.StatusInternalServerError)
		return
	}

	subnetID, err := getIMDSValue(ctx, token, "/latest/meta-data/network/interfaces/macs/")
	if err != nil {
		http.Error(w, "failed to get mac list: "+err.Error(), http.StatusInternalServerError)
		return
	}
	mac := strings.TrimSuffix(strings.TrimSpace(subnetID), "/")

	subnet, err := getIMDSValue(ctx, token, "/latest/meta-data/network/interfaces/macs/"+mac+"/subnet-id")
	if err != nil {
		http.Error(w, "failed to get subnet-id: "+err.Error(), http.StatusInternalServerError)
		return
	}

	vpcID, err := getIMDSValue(ctx, token, "/latest/meta-data/network/interfaces/macs/"+mac+"/vpc-id")
	if err != nil {
		http.Error(w, "failed to get vpc-id: "+err.Error(), http.StatusInternalServerError)
		return
	}

	localIP, err := getIMDSValue(ctx, token, "/latest/meta-data/local-ipv4")
	if err != nil {
		http.Error(w, "failed to get local-ipv4: "+err.Error(), http.StatusInternalServerError)
		return
	}

	region := az[:len(az)-1]

	tags, _ := getInstanceTags(ctx, token)

	cfg, err := awsconfig.LoadDefaultConfig(ctx, awsconfig.WithRegion(region))
	if err != nil {
		http.Error(w, "failed to load aws config: "+err.Error(), http.StatusInternalServerError)
		return
	}

	ec2Client := ec2.NewFromConfig(cfg)

	subnetCIDR := ""
	vpcName := ""

	subnetOut, err := ec2Client.DescribeSubnets(ctx, &ec2.DescribeSubnetsInput{
		SubnetIds: []string{subnet},
	})
	if err == nil && len(subnetOut.Subnets) > 0 && subnetOut.Subnets[0].CidrBlock != nil {
		subnetCIDR = aws.ToString(subnetOut.Subnets[0].CidrBlock)
	}

	vpcOut, err := ec2Client.DescribeVpcs(ctx, &ec2.DescribeVpcsInput{
		VpcIds: []string{vpcID},
	})
	if err == nil && len(vpcOut.Vpcs) > 0 {
		vpcName = findTagValue(vpcOut.Vpcs[0].Tags, "Name")
	}

	resp := MetadataResponse{
		InstanceID: instanceID,
		Region:     region,
		AZ:         az,
		SubnetID:   subnet,
		SubnetCIDR: subnetCIDR,
		VpcID:      vpcID,
		VpcName:    vpcName,
		InternalIP: localIP,
		Tags:       tags,
	}

	writeJSON(w, http.StatusOK, resp)
}

func getIMDSToken(ctx context.Context) (string, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodPut, "http://169.254.169.254/latest/api/token", nil)
	if err != nil {
		return "", err
	}
	req.Header.Set("X-aws-ec2-metadata-token-ttl-seconds", "21600")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("imdsv2 token request failed: %s: %s", resp.Status, string(body))
	}

	b, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}

	return string(b), nil
}

func getIMDSValue(ctx context.Context, token, path string) (string, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, "http://169.254.169.254"+path, nil)
	if err != nil {
		return "", err
	}
	req.Header.Set("X-aws-ec2-metadata-token", token)

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("imds request failed: %s: %s", resp.Status, string(body))
	}

	b, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}

	return strings.TrimSpace(string(b)), nil
}

func getInstanceTags(ctx context.Context, token string) (map[string]string, error) {
	result := map[string]string{}

	keysBody, err := getIMDSValue(ctx, token, "/latest/meta-data/tags/instance")
	if err != nil {
		return result, err
	}

	keys := strings.Split(keysBody, "\n")
	for _, k := range keys {
		k = strings.TrimSpace(k)
		if k == "" {
			continue
		}
		v, err := getIMDSValue(ctx, token, "/latest/meta-data/tags/instance/"+k)
		if err == nil {
			result[k] = v
		}
	}

	return result, nil
}

func findTagValue(tags []ec2types.Tag, key string) string {
	for _, t := range tags {
		if aws.ToString(t.Key) == key {
			return aws.ToString(t.Value)
		}
	}
	return ""
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

func loggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		host, _, _ := net.SplitHostPort(r.RemoteAddr)
		log.Printf("%s %s %s from=%s", r.Method, r.URL.Path, r.Proto, host)
		next.ServeHTTP(w, r)
	})
}