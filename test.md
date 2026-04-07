

# Check service status
sudo systemctl status go-api

# View logs 
sudo journalctl -u go-api -f

# Verify binary exists
ls -l /home/ec2-user/app

# Test locally on the instance
curl http://localhost:8080/healthz

# Test from your machine
curl http://<your-ec2-public-ip>:8080/healthz

# Test all endpoints
curl http://<your-ec2-public-ip>:8080/hello
curl "http://<your-ec2-public-ip>:8080/add?a=3&b=4"
curl http://<your-ec2-public-ip>:8080/metadata