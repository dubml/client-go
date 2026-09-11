package tests

import (
	"context"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"

	clientset "github.com/dubml/client-go/pkg/clientset/versioned"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/rest"
)

func TestTransitServiceClientUsesRegisteredKindAndResource(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet || r.URL.Path != "/apis/networking.dubbo.apache.org/v1alpha3/namespaces/team/transitservices" {
			t.Errorf("incorrect Kubernetes request: %s %s", r.Method, r.URL.Path)
			http.Error(w, "unexpected resource", http.StatusNotFound)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprint(w, `{"apiVersion":"networking.dubbo.apache.org/v1alpha3","kind":"TransitServiceList","items":[{"metadata":{"name":"chat","namespace":"team"},"spec":{"ai":{"provider":{"openai":{}},"models":["chat-model"]}}}]}`)
	}))
	defer server.Close()
	client, err := clientset.NewForConfig(&rest.Config{Host: server.URL})
	if err != nil {
		t.Fatal(err)
	}
	list, err := client.NetworkingV1alpha3().TransitServices("team").List(context.Background(), metav1.ListOptions{})
	if err != nil {
		t.Fatal(err)
	}
	if len(list.Items) != 1 || list.Items[0].Name != "chat" {
		t.Fatalf("incorrect decoded list: %#v", list)
	}
	ai := list.Items[0].Spec.GetAi()
	if ai == nil || ai.Provider.GetOpenai() == nil || len(ai.Models) != 1 || ai.Models[0] != "chat-model" {
		t.Fatalf("TransitService protobuf spec was not decoded: %v", ai)
	}
}
