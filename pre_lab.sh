#!/bin/bash
# ==========================================================
# CentOS 7 Lab Environment Setup Script – v2025.10.1
# Author : Haroon Ur Rasheed
# Purpose: Prepare CentOS 7 VM for OpenShift, Kubernetes & DevOps Labs
# ==========================================================

set -e

echo "=== Step 1: Configure reliable DNS servers ==="
sudo bash -c 'cat > /etc/resolv.conf <<EOF
nameserver 8.8.8.8
nameserver 1.1.1.1
EOF'
echo "✅ DNS configured:"
cat /etc/resolv.conf

echo
echo "=== Step 2: Restore CentOS 7 Vault repositories ==="
sudo sed -i 's|^mirrorlist=|#mirrorlist=|g' /etc/yum.repos.d/CentOS-*
sudo sed -i 's|^#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*
sudo yum clean all
sudo yum repolist
echo "✅ Repositories restored"

echo
echo "=== Step 3: Create 2 GB swapfile ==="
if [ ! -f /swapfile ]; then
  sudo fallocate -l 2G /swapfile
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile
  echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
  sudo swapon /swapfile
else
  echo "Swapfile already exists, skipping creation."
fi
echo "✅ Swap active:"
free -h

echo
echo "=== Step 4: Install essential tools ==="
sudo yum install -y epel-release git curl wget nano net-tools unzip tar which
echo "✅ Essentials installed"

echo
echo "=== Step 5: Install Docker CE (v26.x) and configure permissions ==="
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install -y docker-ce docker-ce-cli containerd.io
sudo systemctl enable docker
sudo systemctl start docker
echo "✅ Docker installed and configured"
docker version || true

# Automatically add user to docker group
USER_NAME=$(whoami)
echo
echo "=== Step 6: Configure Docker permissions for user '$USER_NAME' ==="
sudo usermod -aG docker "$USER_NAME"
echo "User '$USER_NAME' added to 'docker' group."
echo "Activating group..."
newgrp docker <<EONG
echo "✅ Group reloaded — verifying Docker access..."
docker ps || echo "⚠️ Please log out and back in if permissions not yet active."
EONG

echo
echo "=== Step 7: Final Verification ==="
docker info || echo "⚠️ Docker info check skipped or requires re-login."
echo
echo "✅ CentOS 7 Lab Environment Setup Complete!"
echo
echo "=== Step 8: Installing kubectl and OpenShift oc CLI ==="

# Kubernetes CLI (kubectl)
K8S_VERSION=v1.28.0
sudo curl -LO "https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm -f kubectl
echo "✅ kubectl installed:"
kubectl version --client

# OpenShift CLI (oc)
OC_VERSION=4.14.17
curl -L "https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${OC_VERSION}/openshift-client-linux-${OC_VERSION}.tar.gz" -o oc.tar.gz
sudo tar -xvf oc.tar.gz -C /usr/local/bin/ oc kubectl
rm -f oc.tar.gz
echo "✅ oc (OpenShift CLI) installed:"
oc version

echo
echo "✅ Kubernetes & OpenShift CLIs successfully configured!"
echo
echo "=== Step 9: Install and Start Minikube (Local Kubernetes Cluster) ==="

# Install Minikube if not already present
if ! command -v minikube &> /dev/null; then
  echo "➡️ Installing Minikube..."
  curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
  sudo install minikube-linux-amd64 /usr/local/bin/minikube
  rm -f minikube-linux-amd64
  echo "✅ Minikube installed successfully:"
  minikube version
else
  echo "✅ Minikube already installed, skipping."
fi

# Start Minikube with Docker driver
echo
echo "➡️ Starting Minikube cluster using Docker driver..."
minikube start --driver=docker --force-systemd=true --memory=2048 --cpus=2 || {
  echo "❌ Failed to start Minikube. Check Docker service or available memory."
  exit 1
}

# Verify cluster is up
echo
echo "✅ Verifying Kubernetes cluster..."
kubectl get nodes -o wide || echo "⚠️ Could not list nodes yet."
kubectl cluster-info || echo "⚠️ Cluster info not available yet."

# Save info
mkdir -p ~/cluster-verification
kubectl get nodes -o wide > ~/cluster-verification/nodes.txt 2>&1 || true
kubectl cluster-info > ~/cluster-verification/cluster-info.txt 2>&1 || true
echo "✅ Cluster verification data saved in ~/cluster-verification/"

echo
echo "✅ Minikube Kubernetes cluster setup complete!"
