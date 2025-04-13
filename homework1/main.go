package main

import (
	"net/http"
	"os"
	"path/filepath"
	"time"

	"github.com/gin-gonic/gin"
)

const (
	logDir  = "/app/logs"
	logFile = "app.log"
)

type LogMessage struct {
	Message string `json:"message"`
}

func ensureLogDir() error {
	return os.MkdirAll(logDir, 0755)
}

func writeLog(message string) error {
	if err := ensureLogDir(); err != nil {
		return err
	}

	f, err := os.OpenFile(filepath.Join(logDir, logFile), os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		return err
	}
	defer f.Close()

	timestamp := time.Now().Format("2006-01-02 15:04:05")
	_, err = f.WriteString(timestamp + " - " + message + "\n")
	return err
}

func readLogs() ([]string, error) {
	content, err := os.ReadFile(filepath.Join(logDir, logFile))
	if err != nil {
		if os.IsNotExist(err) {
			return []string{}, nil
		}
		return nil, err
	}
	return []string{string(content)}, nil
}

func main() {
	r := gin.Default()

	if err := ensureLogDir(); err != nil {
		panic(err)
	}

	welcomeMessage := os.Getenv("WELCOME_MESSAGE")
	if welcomeMessage == "" {
		welcomeMessage = "Welcome to the custom app"
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "5000" 
	}

	r.GET("/", func(c *gin.Context) {
		c.String(http.StatusOK, welcomeMessage)
	})

	r.GET("/status", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok"})
	})

	r.POST("/log", func(c *gin.Context) {
		var logMsg LogMessage
		if err := c.ShouldBindJSON(&logMsg); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request"})
			return
		}

		if err := writeLog(logMsg.Message); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to write log"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"status": "logged"})
	})

	r.GET("/logs", func(c *gin.Context) {
		logs, err := readLogs()
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to read logs"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"logs": logs})
	})

	r.Run(":" + port)
}
