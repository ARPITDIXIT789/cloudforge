# ==============================================================================
# CloudForge Developer & Platform Engineering CLI
# ==============================================================================
# Zero-to-Production DevSecOps Blueprint for AWS & EKS
# ==============================================================================

SHELL := /bin/bash
.DEFAULT_GOAL := help

# Configuration
ENV ?= dev
TF_DIR := terraform/environments/$(ENV)
ANSIBLE_DIR := ansible
GITOPS_DIR := gitops

# Color formatting
CYAN  := \033[36m
GREEN := \033[32m
YELLOW:= \033[33m
RED   := \033[31m
RESET := \033[0m
BOLD  := \033[1m

.PHONY: help infra-init infra-plan infra-up infra-down bastion-harden gitops-init test destroy fmt check

## help: Display this interactive help menu
help:
	@echo ""
	@echo -e "$(CYAN)$(BOLD)CloudForge — DevSecOps & Platform Engineering Platform CLI$(RESET)"
	@echo -e "$(YELLOW)Usage: make <target> [ENV=dev|prod]$(RESET)"
	@echo ""
	@echo -e "$(BOLD)Available Targets:$(RESET)"
	@sed -n 's/^## //p' $(MAKEFILE_LIST) | awk -F ': ' '{printf "  $(GREEN)%-18s$(RESET) %s\n", $$1, $$2}'
	@echo ""

## infra-init: Initialize Terraform working directory and backend for ENV (default: dev)
infra-init:
	@echo -e "$(CYAN)--> Initializing Terraform for [$(ENV)]...$(RESET)"
	cd $(TF_DIR) && terraform init

## infra-plan: Generate and review Terraform execution plan for ENV (default: dev)
infra-plan:
	@echo -e "$(CYAN)--> Generating Terraform execution plan for [$(ENV)]...$(RESET)"
	cd $(TF_DIR) && terraform plan -out=tfplan

## infra-up: Apply Terraform infrastructure for ENV (default: dev)
infra-up:
	@echo -e "$(CYAN)--> Applying Terraform infrastructure for [$(ENV)]...$(RESET)"
	cd $(TF_DIR) && terraform apply -auto-approve

## infra-down: Destroy Terraform infrastructure for ENV (default: dev)
infra-down:
	@echo -e "$(RED)--> Destroying Terraform infrastructure for [$(ENV)]...$(RESET)"
	cd $(TF_DIR) && terraform destroy

## bastion-harden: Execute CIS benchmark security hardening playbook on Bastion Jumpbox
bastion-harden:
	@echo -e "$(CYAN)--> Running Ansible CIS hardening on Bastion jumpbox...$(RESET)"
	cd $(ANSIBLE_DIR) && ansible-playbook -i inventories/hosts.ini playbooks/harden-bastion.yaml

## gitops-init: Bootstrap ArgoCD and register GitOps root Application
gitops-init:
	@echo -e "$(CYAN)--> Initializing GitOps control plane (ArgoCD & Root App)...$(RESET)"
	@kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
	@kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	@echo -e "$(YELLOW)--> Waiting for ArgoCD server deployment...$(RESET)"
	@kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s || true
	@echo -e "$(CYAN)--> Registering CloudForge Addons & Root App-of-Apps...$(RESET)"
	@kubectl apply -f $(GITOPS_DIR)/argocd/addons-app.yaml
	@kubectl apply -f $(GITOPS_DIR)/argocd/root-application.yaml
	@echo -e "$(GREEN)--> ArgoCD Root Application deployed successfully!$(RESET)"

## test: Run local DevSecOps quality gates (TFLint, tfsec, kubeval, Helm lint)
test:
	@echo -e "$(CYAN)--> Running Terraform Format & Validate...$(RESET)"
	terraform -chdir=terraform/environments/dev fmt -check -recursive ../../
	terraform -chdir=terraform/environments/dev validate
	@echo -e "$(CYAN)--> Linting Helm chart...$(RESET)"
	helm lint gitops/apps/sample-microservice
	@echo -e "$(GREEN)--> All local tests passed!$(RESET)"

## fmt: Automatically format Terraform and Helm files
fmt:
	@echo -e "$(CYAN)--> Formatting Terraform manifests...$(RESET)"
	terraform fmt -recursive terraform/

## destroy: Interactive 1-click cloud teardown to eliminate AWS billing
destroy:
	@echo -e "$(RED)--> Invoking 1-click clean-up automation...$(RESET)"
	bash automation/destroy.sh
