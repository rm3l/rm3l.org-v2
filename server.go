package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"
)

const (
	defaultDir  = "public/"
	defaultPort = 8888
)

func main() {

	dir := os.Getenv("WEBSITE_DIR")
	if dir == "" {
		dir = defaultDir
	}

	port := defaultPort
	if portEnvVar, ok := os.LookupEnv("PORT"); ok {
		var err error
		if port, err = strconv.Atoi(portEnvVar); err != nil {
			log.Fatal(err)
		}
	}

	http.Handle("/", http.FileServer(http.Dir(dir)))

	log.Fatal(http.ListenAndServe(fmt.Sprintf(":%d", port), logRequest(http.DefaultServeMux)))
}

func logRequest(h http.Handler) http.Handler {
	fn := func(w http.ResponseWriter, r *http.Request) {

		// call the original http.Handler we're wrapping
		start := time.Now()
		h.ServeHTTP(w, r)
		duration := time.Since(start)

		// gather information about request and log it
		uri := r.URL.String()
		method := r.Method
		referer := r.Header.Get("Referer")
		userAgent := r.Header.Get("User-Agent")
		ipaddr := requestGetRemoteAddress(r)

		log.Printf("\"%s %s\" ip=%q referer=%q user-agent=%q: %v\n",
			method, uri, ipaddr, referer, userAgent, duration)
	}

	// http.HandlerFunc wraps a function so that it
	// implements http.Handler interface
	return http.HandlerFunc(fn)
}

// Request.RemoteAddress contains port, which we want to remove i.e.:
// "[::1]:58292" => "[::1]"
func ipAddrFromRemoteAddr(s string) string {
	idx := strings.LastIndex(s, ":")
	if idx == -1 {
		return s
	}
	return s[:idx]
}

// requestGetRemoteAddress returns ip address of the client making the request,
// taking into account http proxies
func requestGetRemoteAddress(r *http.Request) string {
	hdr := r.Header
	hdrRealIP := hdr.Get("X-Real-Ip")
	hdrForwardedFor := hdr.Get("X-Forwarded-For")
	if hdrRealIP == "" && hdrForwardedFor == "" {
		return ipAddrFromRemoteAddr(r.RemoteAddr)
	}
	if hdrForwardedFor != "" {
		// X-Forwarded-For is potentially a list of addresses separated with ","
		parts := strings.Split(hdrForwardedFor, ",")
		for i, p := range parts {
			parts[i] = strings.TrimSpace(p)
		}
		// TODO: should return first non-local address
		return parts[0]
	}
	return hdrRealIP
}
