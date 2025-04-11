# Directory-Space-Monitor
Directory Space Monitor is a Bash script designed to monitor user directory usage on Linux systems. The user can set limits for the maximum directory size, maximum number of files in directories, and define forbidden file types (e.g., extensions). The script automatically checks these limits and, when exceeded, deletes the oldest files to maintain order.

- The user interface is based on Zenity.
- All actions are logged to a log.txt file.
- The script runs in the background, continuously monitoring disk space and ensuring the system stays organized.
- Users can also manually delete files that don't meet the specified criteria.
