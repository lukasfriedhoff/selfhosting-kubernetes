package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	_ "github.com/go-sql-driver/mysql"
)

type config struct {
	appPort       int
	dbHost        string
	dbPort        int
	dbUser        string
	dbPassword    string
	dbName        string
	dbMaxRetries  int
	dbRetryDelay  time.Duration
	dbPingTimeout time.Duration
}

type app struct {
	db *sql.DB
}

type demoName struct {
	ID   int64  `json:"id"`
	Name string `json:"name"`
}

type createNameRequest struct {
	Name string `json:"name"`
}

func main() {
	cfg := loadConfig()
	dsn := fmt.Sprintf(
		"%s:%s@tcp(%s:%d)/%s?parseTime=true&charset=utf8mb4&collation=utf8mb4_unicode_ci",
		cfg.dbUser,
		cfg.dbPassword,
		cfg.dbHost,
		cfg.dbPort,
		cfg.dbName,
	)

	db, err := sql.Open("mysql", dsn)
	if err != nil {
		log.Fatalf("open db: %v", err)
	}
	defer db.Close()

	if err := waitForDB(db, cfg.dbMaxRetries, cfg.dbRetryDelay, cfg.dbPingTimeout); err != nil {
		log.Fatalf("database unavailable: %v", err)
	}

	a := &app{db: db}

	mux := http.NewServeMux()
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/" {
			http.NotFound(w, r)
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{
			"message":   "go mariadb demo api",
			"endpoints": []string{"GET /healthz", "GET /names", "POST /names"},
		})
	})
	mux.HandleFunc("/healthz", a.handleHealthz)
	mux.HandleFunc("/names", a.handleNames)

	addr := ":" + strconv.Itoa(cfg.appPort)
	srv := &http.Server{
		Addr:              addr,
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
	}

	log.Printf("listening on %s", addr)
	if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		log.Fatalf("server error: %v", err)
	}
}

func loadConfig() config {
	return config{
		appPort:       getEnvInt("APP_PORT", 8080),
		dbHost:        getEnv("DB_HOST", "127.0.0.1"),
		dbPort:        getEnvInt("DB_PORT", 3306),
		dbUser:        getEnv("DB_USER", "root"),
		dbPassword:    getEnv("DB_PASSWORD", "workshop123"),
		dbName:        getEnv("DB_NAME", "workshop"),
		dbMaxRetries:  getEnvInt("DB_MAX_RETRIES", 15),
		dbRetryDelay:  time.Duration(getEnvInt("DB_RETRY_DELAY_SECONDS", 2)) * time.Second,
		dbPingTimeout: time.Duration(getEnvInt("DB_PING_TIMEOUT_SECONDS", 3)) * time.Second,
	}
}

func waitForDB(db *sql.DB, maxRetries int, retryDelay, pingTimeout time.Duration) error {
	if maxRetries < 1 {
		maxRetries = 1
	}

	var lastErr error
	for i := 1; i <= maxRetries; i++ {
		ctx, cancel := context.WithTimeout(context.Background(), pingTimeout)
		err := db.PingContext(ctx)
		cancel()
		if err == nil {
			return nil
		}

		lastErr = err
		log.Printf("db ping failed (%d/%d): %v", i, maxRetries, err)
		if i < maxRetries {
			time.Sleep(retryDelay)
		}
	}

	return fmt.Errorf("db ping failed after %d retries: %w", maxRetries, lastErr)
}

func (a *app) handleHealthz(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}

	if err := a.db.PingContext(r.Context()); err != nil {
		writeError(w, http.StatusServiceUnavailable, "database unavailable")
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (a *app) handleNames(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		a.listNames(w, r)
	case http.MethodPost:
		a.createName(w, r)
	default:
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
	}
}

func (a *app) listNames(w http.ResponseWriter, r *http.Request) {
	rows, err := a.db.QueryContext(r.Context(), `
		SELECT id, name
		FROM demo_names
		ORDER BY id
	`)
	if err != nil {
		log.Printf("list names query failed: %v", err)
		writeError(w, http.StatusInternalServerError, "query failed")
		return
	}
	defer rows.Close()

	names := make([]demoName, 0)
	for rows.Next() {
		var n demoName
		if err := rows.Scan(&n.ID, &n.Name); err != nil {
			log.Printf("list names scan failed: %v", err)
			writeError(w, http.StatusInternalServerError, "scan failed")
			return
		}
		names = append(names, n)
	}

	if err := rows.Err(); err != nil {
		log.Printf("list names rows error: %v", err)
		writeError(w, http.StatusInternalServerError, "rows failed")
		return
	}

	writeJSON(w, http.StatusOK, names)
}

func (a *app) createName(w http.ResponseWriter, r *http.Request) {
	defer r.Body.Close()

	var req createNameRequest
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	if err := dec.Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid json")
		return
	}

	req.Name = strings.TrimSpace(req.Name)
	if req.Name == "" {
		writeError(w, http.StatusBadRequest, "name is required")
		return
	}

	result, err := a.db.ExecContext(r.Context(), `
		INSERT INTO demo_names (name)
		VALUES (?)
	`, req.Name)
	if err != nil {
		log.Printf("insert name failed: %v", err)
		writeError(w, http.StatusInternalServerError, "insert failed")
		return
	}

	id, err := result.LastInsertId()
	if err != nil {
		log.Printf("read last insert id failed: %v", err)
		writeError(w, http.StatusInternalServerError, "insert id failed")
		return
	}

	writeJSON(w, http.StatusCreated, demoName{ID: id, Name: req.Name})
}

func writeJSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(payload); err != nil {
		log.Printf("write json failed: %v", err)
	}
}

func writeError(w http.ResponseWriter, status int, message string) {
	writeJSON(w, status, map[string]string{"error": message})
}

func getEnv(key, fallback string) string {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback
	}
	return value
}

func getEnvInt(key string, fallback int) int {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback
	}

	parsed, err := strconv.Atoi(value)
	if err != nil {
		log.Printf("invalid int for %s=%q, using fallback %d", key, value, fallback)
		return fallback
	}
	return parsed
}
