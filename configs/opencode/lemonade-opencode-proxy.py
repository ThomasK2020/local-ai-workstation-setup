#!/usr/bin/env python3
import http.server
import socketserver
import urllib.request
import json
import sys
import uuid

TARGET_HOST = "http://127.0.0.1:13305"
LISTEN_PORT = 13306

def flatten_messages(messages):
    cleaned = []
    for msg in messages:
        if not isinstance(msg, dict):
            continue
        c = msg.get("content")
        if isinstance(c, list):
            text_parts = []
            for part in c:
                if isinstance(part, dict) and part.get("type") == "text":
                    text_parts.append(part.get("text", ""))
                elif isinstance(part, str):
                    text_parts.append(part)
            c = "\n".join(text_parts)
        cleaned.append({
            "role": msg.get("role", "user"),
            "content": c if c is not None else ""
        })
    return cleaned

class ProxyHandler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        body_bytes = self.rfile.read(length)
        
        # Translate /v1/responses or /v1/chat/completions
        try:
            data = json.loads(body_bytes)
            
            # Extract and flatten messages/input
            input_msgs = data.get("input") or data.get("messages") or []
            flattened_msgs = flatten_messages(input_msgs)
            
            if self.path == "/v1/responses":
                chat_req = {
                    "model": data.get("model", "Gemma-4-31B-it-GGUF"),
                    "messages": flattened_msgs,
                    "stream": True,
                    "reasoning_format": "none"
                }
                if "max_output_tokens" in data:
                    chat_req["max_tokens"] = data["max_output_tokens"]
                if "tools" in data:
                    chat_req["tools"] = data["tools"]
                if "tool_choice" in data:
                    chat_req["tool_choice"] = data["tool_choice"]

                target_url = TARGET_HOST + "/v1/chat/completions"
                headers = {
                    "Content-Type": "application/json",
                    "Authorization": "Bearer lemonade"
                }
                
                req = urllib.request.Request(target_url, data=json.dumps(chat_req).encode("utf-8"), headers=headers)
                
                with urllib.request.urlopen(req) as resp:
                    self.send_response(200)
                    self.send_header("Content-Type", "text/event-stream")
                    self.send_header("Cache-Control", "no-cache")
                    self.send_header("Connection", "keep-alive")
                    self.end_headers()
                    
                    resp_id = "resp_" + uuid.uuid4().hex[:16]
                    msg_id = "msg_" + uuid.uuid4().hex[:16]

                    self.send_event("response.created", {"type": "response.created", "response": {"id": resp_id, "object": "response", "status": "in_progress"}})
                    self.send_event("response.in_progress", {"type": "response.in_progress", "response": {"id": resp_id, "object": "response", "status": "in_progress"}})
                    self.send_event("response.output_item.added", {"type": "response.output_item.added", "item": {"id": msg_id, "type": "message", "role": "assistant", "content": [], "status": "in_progress"}})
                    self.send_event("response.content_part.added", {"type": "response.content_part.added", "item_id": msg_id, "part": {"type": "output_text", "text": ""}})

                    while True:
                        line = resp.readline()
                        if not line:
                            break
                        line_str = line.decode("utf-8", errors="ignore").strip()
                        if not line_str.startswith("data: "):
                            continue
                        
                        raw_data = line_str[6:]
                        if raw_data == "[DONE]":
                            break
                        
                        try:
                            chunk = json.loads(raw_data)
                            choices = chunk.get("choices", [])
                            if choices:
                                delta = choices[0].get("delta", {})
                                content = delta.get("content")
                                if content:
                                    self.send_event("response.output_text.delta", {
                                        "type": "response.output_text.delta",
                                        "item_id": msg_id,
                                        "delta": content
                                    })
                        except Exception:
                            pass

                    self.send_event("response.content_part.done", {"type": "response.content_part.done", "item_id": msg_id, "part": {"type": "output_text", "text": ""}})
                    self.send_event("response.output_item.done", {"type": "response.output_item.done", "item": {"id": msg_id, "type": "message", "role": "assistant", "status": "completed"}})
                    self.send_event("response.done", {"type": "response.done", "response": {"id": resp_id, "status": "completed"}})
                    return
            else:
                data["messages"] = flattened_msgs
                data["reasoning_format"] = "none"
                body_bytes = json.dumps(data).encode("utf-8")

        except Exception as e:
            pass

        target_url = TARGET_HOST + self.path
        req = urllib.request.Request(target_url, data=body_bytes, headers={"Content-Type": "application/json", "Authorization": "Bearer lemonade"})
        try:
            with urllib.request.urlopen(req) as resp:
                self.send_response(resp.status)
                for k, v in resp.getheaders():
                    if k.lower() not in ("transfer-encoding", "content-length"):
                        self.send_header(k, v)
                self.end_headers()
                while True:
                    line = resp.readline()
                    if not line:
                        break
                    self.wfile.write(line)
                    self.wfile.flush()
        except Exception as e:
            try:
                self.send_error(500, str(e))
            except Exception:
                pass

    def send_event(self, event_type, data_obj):
        evt = f"event: {event_type}\ndata: {json.dumps(data_obj)}\n\n".encode("utf-8")
        self.wfile.write(evt)
        self.wfile.flush()

    def do_GET(self):
        target_url = TARGET_HOST + self.path
        req = urllib.request.Request(target_url)
        try:
            with urllib.request.urlopen(req) as resp:
                self.send_response(resp.status)
                for k, v in resp.getheaders():
                    self.send_header(k, v)
                self.end_headers()
                self.wfile.write(resp.read())
        except Exception as e:
            try:
                self.send_error(500, str(e))
            except Exception:
                pass

    def log_message(self, format, *args):
        pass

class ThreadedTCPServer(socketserver.ThreadingMixIn, socketserver.TCPServer):
    daemon_threads = True
    allow_reuse_address = True

if __name__ == "__main__":
    server = ThreadedTCPServer(("127.0.0.1", LISTEN_PORT), ProxyHandler)
    server.serve_forever()
