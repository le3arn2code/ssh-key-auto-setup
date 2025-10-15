#!/bin/bash
# ==========================================================
# CentOS 7 Lab Environment Setup Script – v2025.10-stable
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

# ----------------------------------------------------------
echo "=== Step 2: Restore CentOS 7 Vault repositories ==="
sudo mkdir -p /etc/yum.repos.d/backup
sudo mv /etc/yum.repos.d/*.repo /etc/yum.repos.d/backup/ 2>/dev/null || true

sudo bash -c 'cat > /etc/yum.repos.d/CentOS-Vault.repo <<EOF
[base]
name=CentOS-7 - Base
baseurl=http://vault.centos.org/7.9.2009/os/\$basearch/
gpgcheck=1
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

[updates]
name=CentOS-7 - Updates
baseurl=http://vault.centos.org/7.9.2009/updates/\$basearch/
gpgcheck=1
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

[extras]
name=CentOS-7 - Extras
baseurl=http://vault.centos.org/7.9.2009/extras/\$basearch/
gpgcheck=1
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
EOF'

sudo yum clean all -q
sudo yum makecache fast -q
sudo yum repolist
echo

# ----------------------------------------------------------
echo "=== Step 3: Create 2 GB swapfile ==="
sudo swapoff -a 2>/dev/null || true
sudo rm -f /swapfile
echo "➡️  Creating swapfile..."
sudo dd if=/dev/zero of=/swapfile bs=1M count=2048 status=progress
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
grep -q "/swapfile" /etc/fstab || echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
echo "✅ Swap active:"
free -h
echo

# ----------------------------------------------------------
echo "=== Step 4: Install essential tools ==="
sudo yum -y install epel-release -q || true
sudo yum -y install git curl wget vim nano net-tools unzip lsof tar which -q
echo "✅ Essentials installed"
echo

# ----------------------------------------------------------
echo "=== Step 5: Install Docker CE (v26.x) and configure permissions ==="
sudo yum -y install yum-utils device-mapper-persistent-data lvm2 -q
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo -q
sudo yum -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin -q

sudo mkdir -p /var/run
sudo systemctl enable docker --now
sleep 3

# Fix Docker group and socket permissions
sudo groupadd docker 2>/dev/null || true
sudo usermod -aG docker $USER
sudo chown root:docker /var/run/docker.sock 2>/dev/null || true
sudo chmod 660 /var/run/docker.sock 2>/dev/null || true
sudo systemctl restart docker
echo "✅ Docker installed and configured"
docker version
echo "🧩 Checking container runtime info:"
docker info --format '{{.ServerVersion}} running with driver: {{.Driver}}' || true
echo

# ----------------------------------------------------------
echo "=== Step 6: Install Minikube v1.37.0 ==="
cd ~
sudo rm -f /usr/local/bin/minikube
curl -Lo minikube https://storage.googleapis.com/minikube/releases/v1.37.0/minikube-linux-amd64
chmod +x minikube
sudo mv minikube /usr/local/bin/
minikube version
echo

# ----------------------------------------------------------
echo "=== Step 7: Install kubectl v1.23.17 (CentOS 7 compatible) ==="
cd ~
sudo rm -f /usr/local/bin/kubectl
curl -LO https://dl.k8s.io/release/v1.23.17/bin/linux/amd64/kubectl
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
kubectl version --client
echo

# ----------------------------------------------------------
echo "=== Step 8: Install oc v4.9.0 (OpenShift client for RHEL 7) ==="
cd ~
sudo rm -f /usr/local/bin/oc
wget -q https://mirror.openshift.com/pub/openshift-v4/clients/ocp/4.9.0/openshift-client-linux.tar.gz
tar -xvf openshift-client-linux.tar.gz
sudo mv oc /usr/local/bin/
echo "✅ oc client installed"
oc version || true
echo

# ----------------------------------------------------------
echo "=== Step 9: Verification Summary ==="
echo "🟢 DNS test:"
ping -c 2 google.com || true
echo
echo "🟢 Repository check:"
sudo yum repolist
echo
echo "🟢 Memory & Swap:"
free -h
echo
echo "🟢 Binaries:"
which docker minikube kubectl oc
echo
docker --version
minikube version
kubectl version --client
oc version || true
echo
echo "✅ Environment is ready for OpenShift and Kubernetes labs!"
echo "------------------------------------------------------"
echo "🚀 Quick Start:"
echo "1️⃣  newgrp docker"
echo "2️⃣  minikube start --driver=docker"
echo "3️⃣  kubectl get nodes"
echo "------------------------------------------------------"
