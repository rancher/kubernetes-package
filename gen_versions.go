package main

import (
	"html/template"
	"os"

	"github.com/rancher/types/apis/management.cattle.io/v3"
	"github.com/sirupsen/logrus"
)

const (
	imageListFileName = "addons_image_list"
	imageListTemplate = `
TILLER_IMAGE={{.Tiller}}
KUBEDNS_IMAGE={{.KubeDNS}}
DNSMASQ_IMAGE={{.DNSmasq}}
GRAFANA_IMAGE={{.Grafana}}
HEAPSTER_IMAGE={{.Heapster}}
INFLUXDB_IMAGE={{.Influxdb}}
DASHBOARD_IMAGE={{.Dashboard}}
DNS_SIDECAR_IMAGE={{.KubeDNSSidecar}}
`
)

func main() {
	k8s_version := os.Getenv("KUBERNETES_PACKAGE_VERSION")
	if k8s_version == "" {
		logrus.Errorf("KUBERNETES_PACKAGE_VERSION version is not set")
		os.Exit(1)
	}
	images, ok := v3.K8SVersionToSystemImages16[k8s_version]
	if !ok {
		logrus.Errorf("Counldn't find images map for $KUBERNETES_PACKAGE_VERSION=\"%s\"", k8s_version)
		os.Exit(1)
	}
	file, err := os.Create(imageListFileName)
	if err != nil {
		logrus.Errorf("Failed to open image list file [%s]: %v", imageListFileName, err)
		os.Exit(1)
	}
	defer file.Close()

	t := template.Must(template.New("imageList").Parse(imageListTemplate))
	if err := t.Execute(file, images); err != nil {
		logrus.Errorf("Failed to compile image list template: %v", err)
		os.Exit(1)
	}
	logrus.Infof("Image list generated using version [%s] map", k8s_version)
}
