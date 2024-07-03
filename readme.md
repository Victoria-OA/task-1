```bash log_message() {
  echo "$(date) - $1" | tee -a "$LOG_FILE"
}
```
