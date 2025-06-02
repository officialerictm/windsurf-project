#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)";
cd "$SCRIPT_DIR" || { printf "%s\\n" "ERROR: Could not change to script directory. Exiting."; exit 1; };

# Initialize console colors
C_RESET=""; C_BOLD=""; C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_CYAN="";
if command -v tput >/dev/null 2>&1 && tput setaf 1 >/dev/null 2>&1; then
    C_RESET=$(tput sgr0); C_BOLD=$(tput bold); C_RED=$(tput setaf 1); C_GREEN=$(tput setaf 2);
    C_YELLOW=$(tput setaf 3); C_BLUE=$(tput setaf 4); C_CYAN=$(tput setaf 6);
fi;

# Define helper functions
print_error() {
    printf "%b\\n" "${C_RED}❌ ERROR: $1${C_RESET}";
}

print_info() {
    printf "%b\\n" "${C_BLUE}ℹ️ INFO: $1${C_RESET}";
}

# Check for dependencies
check_dependency() {
    if ! command -v "$1" >/dev/null 2>&1; then
        print_error "Required dependency '$1' is not installed."
        return 1
    fi
    return 0
}

printf "%b\\n" "${C_BOLD}${C_GREEN}🚀 Starting Leonardo AI USB Environment (Linux)...${C_RESET}";

printf "%b\\n" "${C_BLUE}Setting up environment variables...${C_RESET}";
# Setup data directory
export OLLAMA_MODELS="$SCRIPT_DIR/.ollama/models";
[ ! -d "$OLLAMA_MODELS" ] && mkdir -p "$OLLAMA_MODELS";
export OLLAMA_HOST="127.0.0.1:11434";

OLLAMA_BIN="$SCRIPT_DIR/runtimes/linux/bin/ollama";
if [ ! -f "$OLLAMA_BIN" ]; then 
    print_error "Ollama binary not found at $OLLAMA_BIN"; 
    read -p "Press Enter to exit."; 
    exit 1; 
fi;

if [ ! -x "$OLLAMA_BIN" ]; then
    printf "%b\\n" "${C_YELLOW}⏳ Ollama binary not executable, attempting to chmod +x...${C_RESET}";
    chmod +x "$OLLAMA_BIN" || { 
        print_error "Failed to make Ollama binary executable. Check permissions or remount USB if needed.";
        read -p "Press Enter to exit."; 
        exit 1; 
    };
fi;

# Setup library path
export LD_LIBRARY_PATH="$SCRIPT_DIR/runtimes/linux/lib:$LD_LIBRARY_PATH";

printf "%b\\n" "${C_BLUE}Starting Ollama server...${C_RESET}";
# Kill any existing ollama process
pkill -f "ollama serve" >/dev/null 2>&1
"$OLLAMA_BIN" serve >/dev/null 2>&1 &
OLLAMA_PID=$!
printf "%b\\n" "${C_GREEN}✅ Ollama server started with PID: $OLLAMA_PID${C_RESET}";

# Wait for server to be ready
WAIT_COUNT=0
printf "%b" "${C_YELLOW}Waiting for Ollama server to initialize...${C_RESET} "
until curl -s "http://$OLLAMA_HOST" >/dev/null 2>&1 || [ $WAIT_COUNT -eq 30 ]; do
    printf "%b" "."
    sleep 1
    ((WAIT_COUNT++))
done
printf "\n"

if [ $WAIT_COUNT -eq 30 ]; then
    print_error "Ollama server failed to start in time. Please check for errors and try again."
    kill $OLLAMA_PID >/dev/null 2>&1
    exit 1
fi

# Check if Node.js is available for the proxy server
WEBUI_PROXY_PORT=8080
USE_PROXY=false

if check_dependency "node"; then
    printf "%b\\n" "${C_BLUE}Starting WebUI proxy server to avoid CORS issues...${C_RESET}"
    
    # Copy the proxy server script if it doesn't exist
    if [ ! -f "$SCRIPT_DIR/webui_server.js" ]; then
        cp "$SCRIPT_DIR/$(basename "$0" .sh)_webui_server.js" "$SCRIPT_DIR/webui_server.js" 2>/dev/null || {
            # If the companion script isn't found, create it inline
            cat > "$SCRIPT_DIR/webui_server.js" << 'EOL'
#!/usr/bin/env node
// Simple HTTP server that serves the WebUI and forwards API requests to Ollama
// This avoids CORS issues by acting as a proxy

const http = require('http');
const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');

// Configuration
const PORT = 8080;
const OLLAMA_API = 'http://127.0.0.1:11434';
const OLLAMA_API_HOST = '127.0.0.1:11434';

// Simple MIME type mapping
const MIME_TYPES = {
  '.html': 'text/html',
  '.css': 'text/css',
  '.js': 'application/javascript',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon'
};

// Create HTTP server
const server = http.createServer((req, res) => {
  console.log(`${req.method} ${req.url}`);
  
  // Handle API proxy requests
  if (req.url.startsWith('/api/')) {
    const options = {
      hostname: '127.0.0.1',
      port: 11434,
      path: req.url,
      method: req.method,
      headers: {
        'Content-Type': 'application/json'
      }
    };
    
    const apiReq = http.request(options, (apiRes) => {
      // Set CORS headers to allow requests
      res.setHeader('Access-Control-Allow-Origin', '*');
      res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
      res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
      
      // Forward status and headers
      res.writeHead(apiRes.statusCode, apiRes.headers);
      
      // Stream response data
      apiRes.pipe(res);
    });
    
    apiReq.on('error', (error) => {
      console.error(`API Request Error: ${error.message}`);
      res.writeHead(500);
      res.end(JSON.stringify({ error: 'Error connecting to Ollama API' }));
    });
    
    // Forward request body to Ollama API
    if (['POST', 'PUT'].includes(req.method)) {
      req.pipe(apiReq);
    } else {
      apiReq.end();
    }
    
    return;
  }
  
  // For OPTIONS requests (preflight CORS)
  if (req.method === 'OPTIONS') {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
    res.writeHead(204);
    res.end();
    return;
  }
  
  // Serve WebUI files
  let filePath = './webui' + (req.url === '/' ? '/index.html' : req.url);
  
  // Check if file exists
  fs.access(filePath, fs.constants.F_OK, (err) => {
    if (err) {
      res.writeHead(404);
      res.end('File not found');
      return;
    }
    
    // Read and serve the file
    fs.readFile(filePath, (err, data) => {
      if (err) {
        res.writeHead(500);
        res.end('Error reading file');
        return;
      }
      
      const ext = path.extname(filePath);
      const contentType = MIME_TYPES[ext] || 'application/octet-stream';
      
      res.setHeader('Content-Type', contentType);
      res.writeHead(200);
      res.end(data);
    });
  });
});

// Start server
server.listen(PORT, () => {
  console.log(`WebUI server running at http://localhost:${PORT}/`);
  console.log(`Proxying API requests to ${OLLAMA_API}`);
});

// Handle server errors
server.on('error', (err) => {
  if (err.code === 'EADDRINUSE') {
    console.error(`Port ${PORT} is already in use. Try a different port.`);
  } else {
    console.error('Server error:', err);
  }
});
EOL
        }
    fi
    
    # Make sure it's executable
    chmod +x "$SCRIPT_DIR/webui_server.js"
    
    # Start the proxy server
    node "$SCRIPT_DIR/webui_server.js" >/dev/null 2>&1 &
    PROXY_PID=$!
    
    if [ $? -eq 0 ]; then
        printf "%b\\n" "${C_GREEN}✅ WebUI proxy server started with PID: $PROXY_PID${C_RESET}"
        USE_PROXY=true
        
        # Wait a moment for the server to start
        sleep 2
    else
        print_info "Failed to start WebUI proxy server. Will try direct file access instead."
    fi
else
    print_info "Node.js not found. Will use direct file access for WebUI (may have CORS issues)."
fi

# List available models
MODELS=$(curl -s "http://$OLLAMA_HOST/api/tags" | grep -o '"name":"[^"]*"' | cut -d'"' -f4 | sort)
if [ -z "$MODELS" ]; then
    print_error "No models found on the USB drive. Please ensure models are installed."
    kill $OLLAMA_PID >/dev/null 2>&1
    [ "$USE_PROXY" = true ] && kill $PROXY_PID >/dev/null 2>&1
    exit 1
fi

# Select model if multiple are available
if [ "$(echo "$MODELS" | wc -l)" -gt 1 ]; then
    printf "%b\\n" "${C_CYAN}📋 Available models:${C_RESET}"
    echo "$MODELS" | nl -w2 -s') '
    
    printf "%b" "${C_YELLOW}Select a model (1-$(echo "$MODELS" | wc -l)): ${C_RESET}"
    read -r model_choice
    
    if ! [[ "$model_choice" =~ ^[0-9]+$ ]] || [ "$model_choice" -lt 1 ] || [ "$model_choice" -gt "$(echo "$MODELS" | wc -l)" ]; then
        model_choice=1
        printf "%b\\n" "${C_YELLOW}⚠️ Invalid choice, using first model.${C_RESET}"
    fi
    
    MODEL=$(echo "$MODELS" | sed -n "${model_choice}p")
else
    MODEL=$MODELS
fi

printf "%b\\n" "${C_GREEN}✅ Using model: ${C_BOLD}$MODEL${C_RESET}"

# Launch Web UI
printf "%b\\n" "${C_BLUE}Launching web interface...${C_RESET}"

# Use the proxy URL if the proxy server is running
if [ "$USE_PROXY" = true ]; then
    WEBUI_URL="http://localhost:$WEBUI_PROXY_PORT/"
    
    if command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$WEBUI_URL" >/dev/null 2>&1 &
    elif command -v gio >/dev/null 2>&1; then
        gio open "$WEBUI_URL" >/dev/null 2>&1 &
    else
        printf "%b\\n" "${C_YELLOW}⚠️ Could not automatically open browser.${C_RESET}"
        printf "%b\\n" "${C_YELLOW}Please manually open: ${C_BOLD}$WEBUI_URL${C_RESET}"
    fi
    
    printf "%b\\n" "${C_GREEN}${C_BOLD}✨ Leonardo AI USB is ready! ✨${C_RESET}"
    printf "%b\\n" "${C_CYAN}🔗 Access Ollama API at: ${C_BOLD}http://$OLLAMA_HOST${C_RESET}"
    printf "%b\\n" "${C_CYAN}🔗 Web UI at: ${C_BOLD}$WEBUI_URL${C_RESET}"
else
    # Fallback to direct file access (which might have CORS issues)
    if command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$SCRIPT_DIR/webui/index.html" >/dev/null 2>&1 &
    elif command -v gio >/dev/null 2>&1; then
        gio open "$SCRIPT_DIR/webui/index.html" >/dev/null 2>&1 &
    else
        printf "%b\\n" "${C_YELLOW}⚠️ Could not automatically open browser.${C_RESET}"
        printf "%b\\n" "${C_YELLOW}Please manually open: ${C_BOLD}$SCRIPT_DIR/webui/index.html${C_RESET}"
    fi
    
    printf "%b\\n" "${C_GREEN}${C_BOLD}✨ Leonardo AI USB is ready! ✨${C_RESET}"
    printf "%b\\n" "${C_CYAN}🔗 Access Ollama API at: ${C_BOLD}http://$OLLAMA_HOST${C_RESET}"
    printf "%b\\n" "${C_CYAN}🔗 Web UI at: ${C_BOLD}$SCRIPT_DIR/webui/index.html${C_RESET}"
    printf "%b\\n" "${C_YELLOW}⚠️ Note: You may encounter CORS issues with the direct file access WebUI.${C_RESET}"
    printf "%b\\n" "${C_YELLOW}   If so, install Node.js for the proxy server feature to work.${C_RESET}"
fi

printf "%b\\n" "${C_YELLOW}ℹ️ Press Ctrl+C to stop the Ollama server when finished.${C_RESET}"

# Keep script running until Ctrl+C
cleanup() {
    printf "\n${C_BLUE}Shutting down services...${C_RESET}"
    # Kill Ollama server
    kill $OLLAMA_PID >/dev/null 2>&1
    # Kill proxy server if running
    [ "$USE_PROXY" = true ] && kill $PROXY_PID >/dev/null 2>&1
    printf "${C_GREEN}✅ Shutdown complete.${C_RESET}\n"
    exit 0
}

trap cleanup INT
wait $OLLAMA_PID
