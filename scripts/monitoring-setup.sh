#!/usr/bin/env bash
# Installs Prometheus + Grafana (kube-prometheus-stack) into the `monitoring`
# namespace on the current kube context. Idempotent — safe to re-run.
#
# Access after install:
#   kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80
#   kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090
#
# Grafana default login: admin / prom-operator

set -euo pipefail

NAMESPACE="monitoring"
RELEASE="monitoring"
CHART="prometheus-community/kube-prometheus-stack"

command -v helm     >/dev/null || { echo "helm not found on PATH" >&2; exit 1; }
command -v kubectl  >/dev/null || { echo "kubectl not found on PATH" >&2; exit 1; }
command -v minikube >/dev/null || { echo "minikube not found on PATH" >&2; exit 1; }

echo ">> Enabling minikube addons (metrics-server, istio-provisioner, istio)"
minikube addons enable metrics-server
minikube addons enable istio-provisioner
minikube addons enable istio

echo ">> Adding prometheus-community helm repo"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update prometheus-community >/dev/null

echo ">> Ensuring namespace '${NAMESPACE}' exists"
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

echo ">> Installing/upgrading ${RELEASE} (${CHART}) in ${NAMESPACE}"
helm upgrade --install "${RELEASE}" "${CHART}" \
  --namespace "${NAMESPACE}" \
  --set grafana.service.type=ClusterIP \
  --set prometheus.prometheusSpec.retention=6h \
  --wait

echo
echo "Done. To access the UIs:"
echo "  Grafana:    kubectl port-forward -n ${NAMESPACE} svc/${RELEASE}-grafana 3000:80"
echo "  Prometheus: kubectl port-forward -n ${NAMESPACE} svc/${RELEASE}-kube-prometheus-prometheus 9090:9090"
echo "  Grafana login: admin / prom-operator"
