#!/bin/bash
# Downloads and extracts the latest Linux builds of node_exporter, Prometheus and Grafana
# into $HOME (the same files offered on prometheus.io/download and grafana.com/grafana/download).
# If a download fails, get the link from those websites and wget it manually.
set -e
cd "$HOME"
latest_asset() {   # $1 = GitHub repo, $2 = text the file name must contain
  curl -s "https://api.github.com/repos/$1/releases/latest" \
    | grep browser_download_url | grep "$2" | head -1 | cut -d '"' -f 4
}
for repo in prometheus/node_exporter prometheus/prometheus; do
  url=$(latest_asset "$repo" "linux-amd64.tar.gz")
  echo "Downloading $url"
  wget -q "$url"
done
tar xf node_exporter-*.tar.gz
tar xf prometheus-*.tar.gz
GVER=$(curl -s https://api.github.com/repos/grafana/grafana/releases/latest \
  | grep '"tag_name"' | cut -d '"' -f 4 | sed 's/^v//')
echo "Downloading Grafana $GVER"
wget -q "https://dl.grafana.com/oss/release/grafana-${GVER}.linux-amd64.tar.gz"
tar xf grafana-*.tar.gz
echo "Done. Extracted folders:"
ls -d "$HOME"/node_exporter-*/ "$HOME"/prometheus-*/ "$HOME"/grafana-*/
