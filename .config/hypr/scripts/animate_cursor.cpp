#include <iostream>
#include <string>
#include <sstream>
#include <vector>
#include <chrono>
#include <thread>
#include <cstdlib>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <cstring>
#include <fstream>
#include <cctype>

// Función para comunicarse con el socket de Hyprland
std::string send_hyprland_cmd(const std::string& cmd) {
    const char* his = std::getenv("HYPRLAND_INSTANCE_SIGNATURE");
    if (!his) return "";

    std::string socket_path = "/run/user/" + std::to_string(getuid()) + "/hypr/" + his + "/.socket.sock";
    if (access(socket_path.c_str(), F_OK) == -1) {
        socket_path = "/tmp/hypr/" + std::string(his) + "/.socket.sock";
    }

    int sock = socket(AF_UNIX, SOCK_STREAM, 0);
    if (sock < 0) return "";

    sockaddr_un addr{};
    addr.sun_family = AF_UNIX;
    std::strncpy(addr.sun_path, socket_path.c_str(), sizeof(addr.sun_path) - 1);

    if (connect(sock, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        close(sock);
        return "";
    }

    send(sock, cmd.c_str(), cmd.length(), 0);

    std::string response;
    char buffer[4096];
    ssize_t n;
    while ((n = recv(sock, buffer, sizeof(buffer) - 1, 0)) > 0) {
        buffer[n] = '\0';
        response.append(buffer);
    }

    close(sock);
    return response;
}

// Función auxiliar rápida para buscar números en el JSON de respuesta
bool get_json_array(const std::string& json, const std::string& key, double& val1, double& val2) {
    size_t pos = json.find("\"" + key + "\":");
    if (pos == std::string::npos) return false;
    
    size_t start = json.find('[', pos);
    size_t comma = json.find(',', start);
    size_t end = json.find(']', comma);
    
    if (start == std::string::npos || comma == std::string::npos || end == std::string::npos) return false;
    
    val1 = std::stod(json.substr(start + 1, comma - start - 1));
    val2 = std::stod(json.substr(comma + 1, end - comma - 1));
    return true;
}

// Obtener el color de cursor generado por Wallust
std::string get_wallust_color() {
    std::string path = "/home/josue/.cache/wallust/colors.json";
    std::ifstream file(path);
    if (!file.is_open()) return "rgb(ffffff)"; // Fallback

    std::string content((std::istreambuf_iterator<char>(file)), std::istreambuf_iterator<char>());
    size_t pos = content.find("\"cursor\":");
    if (pos == std::string::npos) {
        pos = content.find("\"color2\":");
    }
    if (pos != std::string::npos) {
        size_t start = content.find('#', pos);
        if (start != std::string::npos && start + 7 <= content.length()) {
            std::string hex = content.substr(start + 1, 6);
            return "rgb(" + hex + ")";
        }
    }
    return "rgb(ffffff)";
}

// Formatear la respuesta de getoption a un formato válido para keyword
std::string format_border_option(const std::string& raw_resp) {
    size_t prefix_pos = raw_resp.find("custom type: ");
    std::string raw_val;
    if (prefix_pos != std::string::npos) {
        size_t start = prefix_pos + 13;
        size_t end = raw_resp.find('\n', start);
        if (end == std::string::npos) raw_val = raw_resp.substr(start);
        else raw_val = raw_resp.substr(start, end - start);
    } else {
        raw_val = raw_resp;
    }

    std::stringstream ss(raw_val);
    std::string token;
    std::string result = "";
    
    while (ss >> token) {
        if (!result.empty()) result += " ";
        
        // Si no tiene 0x, rgb, rgba ni deg, y es un código hexadecimal de 6 u 8 caracteres, añadir 0x
        if (token.find("0x") == std::string::npos && 
            token.find("rgb") == std::string::npos && 
            token.find("rgba") == std::string::npos && 
            token.find("deg") == std::string::npos) {
            bool is_hex = true;
            for (char c : token) {
                if (!std::isxdigit(c)) {
                    is_hex = false;
                    break;
                }
            }
            if (is_hex && (token.length() == 6 || token.length() == 8)) {
                result += "0x" + token;
                continue;
            }
        }
        result += token;
    }
    return result;
}

int main(int argc, char* argv[]) {
    if (argc < 2) {
        std::cerr << "Uso: " << argv[0] << " <l|r|u|d>" << std::endl;
        return 1;
    }
    std::string direction = argv[1];

    // 1. Obtener la posición inicial del cursor y color original del borde
    std::string pos_resp = send_hyprland_cmd("cursorpos");
    double start_x = 960, start_y = 540;
    size_t comma_pos = pos_resp.find(',');
    if (comma_pos != std::string::npos) {
        start_x = std::stod(pos_resp.substr(0, comma_pos));
        start_y = std::stod(pos_resp.substr(comma_pos + 1));
    }

    std::string orig_border_resp = send_hyprland_cmd("getoption general:col.active_border");
    std::string original_border = format_border_option(orig_border_resp);
    std::string wallust_color = get_wallust_color();

    // 2. Mover el foco de la ventana
    send_hyprland_cmd("dispatch movefocus " + direction);

    // 3. Obtener la posición y tamaño de la nueva ventana enfocada
    std::string win_resp = send_hyprland_cmd("j/activewindow");
    double at_x, at_y, size_x, size_y;
    if (!get_json_array(win_resp, "at", at_x, at_y) || !get_json_array(win_resp, "size", size_x, size_y)) {
        return 0; // Si no hay ventana en esa dirección
    }

    double end_x = at_x + size_x / 2.0;
    double end_y = at_y + size_y / 2.0;

    // 4. Activar el color de Wallust en el borde activo temporalmente
    send_hyprland_cmd("keyword general:col.active_border " + wallust_color);

    // 5. Parámetros de la animación
    int steps = 10;
    int sleep_ms = 6; // ~60ms de duración total

    for (int i = 1; i <= steps; ++i) {
        double t = (double)i / steps;
        double factor = t * (2.0 - t); // Curve Ease-Out Quadratic

        int curr_x = static_cast<int>(start_x + (end_x - start_x) * factor);
        int curr_y = static_cast<int>(start_y + (end_y - start_y) * factor);

        send_hyprland_cmd("dispatch movecursor " + std::to_string(curr_x) + " " + std::to_string(curr_y));
        std::this_thread::sleep_for(std::chrono::milliseconds(sleep_ms));
    }

    // 6. Restaurar el color de borde original al finalizar la animación
    if (!original_border.empty()) {
        send_hyprland_cmd("keyword general:col.active_border " + original_border);
    }

    return 0;
}
