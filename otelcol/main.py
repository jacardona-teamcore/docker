from http.server import BaseHTTPRequestHandler, HTTPServer

class MyHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-type', 'text/plain')
        self.end_header()
        self.wfile.write("Hola")

if __name__ == '__main__':
    server_address = ('', 8080)
    httpd = HTTPServer(server_address, MyHandler)
    print("Servidor iniciado en el puerto 8080")
    httpd.serve_forever()