package email

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
)

// Sender sends emails via the Resend API.
type Sender struct {
	APIKey string
	From   string // e.g. "Quiz Battle <noreply@yourdomain.com>"
}

// NewSender creates a Resend email sender.
func NewSender(apiKey, from string) *Sender {
	return &Sender{APIKey: apiKey, From: from}
}

// SendCode sends a verification code email.
func (s *Sender) SendCode(to, code, purpose string) error {
	subject := subjectForPurpose(purpose)
	html := fmt.Sprintf(`
		<div style="font-family:sans-serif;max-width:400px;margin:0 auto;padding:24px;">
			<h2 style="color:#FFC107;">Quiz Battle</h2>
			<p>%s</p>
			<div style="background:#1A1A2E;color:#FFC107;font-size:32px;letter-spacing:8px;text-align:center;padding:16px;border-radius:8px;font-weight:bold;">
				%s
			</div>
			<p style="color:#666;font-size:13px;margin-top:16px;">This code expires in 10 minutes. If you didn't request this, ignore this email.</p>
		</div>
	`, messageForPurpose(purpose), code)

	payload, _ := json.Marshal(map[string]interface{}{
		"from":    s.From,
		"to":      []string{to},
		"subject": subject,
		"html":    html,
	})

	req, err := http.NewRequest("POST", "https://api.resend.com/emails", bytes.NewReader(payload))
	if err != nil {
		return fmt.Errorf("create request: %w", err)
	}
	req.Header.Set("Authorization", "Bearer "+s.APIKey)
	req.Header.Set("Content-Type", "application/json")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return fmt.Errorf("send email: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		var body map[string]interface{}
		json.NewDecoder(resp.Body).Decode(&body)
		return fmt.Errorf("resend API error %d: %v", resp.StatusCode, body)
	}

	return nil
}

func subjectForPurpose(purpose string) string {
	switch purpose {
	case "login":
		return "Your Quiz Battle login code"
	case "reset":
		return "Reset your Quiz Battle password"
	case "link":
		return "Link your email to Quiz Battle"
	default:
		return "Your Quiz Battle verification code"
	}
}

func messageForPurpose(purpose string) string {
	switch purpose {
	case "login":
		return "Enter this code to log in to your account:"
	case "reset":
		return "Enter this code to reset your password:"
	case "link":
		return "Enter this code to link your email:"
	default:
		return "Your verification code is:"
	}
}
