#!/usr/bin/env bash
set -euo pipefail

# Git Offline Bundle Manager - 快速配置测试脚本 (Bash版本)
# 快速验证配置文件是否正确，检查路径、Git配置等关键设置

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# 默认配置
DEFAULT_CONFIG_FILE="config.json"
CONFIG_FILE="${CONFIG_FILE:-$DEFAULT_CONFIG_FILE}"

# 环境变量
ENVIRONMENT="${1:-}"

# 状态输出函数
write_status() {
    local message="$1"
    local status="${2:-INFO}"
    local timestamp=$(date +"%H:%M:%S")
    
    case $status in
        "OK")
            echo -e "[$timestamp] [${GREEN}OK${NC}] $message"
            ;;
        "ERROR")
            echo -e "[$timestamp] [${RED}ERROR${NC}] $message"
            ;;
        "WARNING")
            echo -e "[$timestamp] [${YELLOW}WARNING${NC}] $message"
            ;;
        "INFO")
            echo -e "[$timestamp] [${CYAN}INFO${NC}] $message"
            ;;
        *)
            echo -e "[$timestamp] [INFO] $message"
            ;;
    esac
}

# 检测当前环境
detect_environment() {
    local detected_env=""
    
    # 检查是否强制指定平台
    if command -v jq &> /dev/null && [[ -f "$CONFIG_FILE" ]]; then
        local force_platform=$(jq -r '.global.platform.force_platform // empty' "$CONFIG_FILE" 2>/dev/null)
        if [[ -n "$force_platform" ]]; then
            case $force_platform in
                "windows") detected_env="offline_windows" ;;
                "ubuntu") detected_env="offline_ubuntu" ;;
                "gitlab") detected_env="gitlab_server" ;;
                *) detected_env="$force_platform" ;;
            esac
        fi
    fi
    
    # 自动检测平台
    if [[ -z "$detected_env" ]]; then
        if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
            detected_env="offline_windows"
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            # 检查是否有GitLab访问权限
            if git remote get-url origin 2>/dev/null | grep -q "gitlab"; then
                detected_env="gitlab_server"
            else
                detected_env="offline_ubuntu"
            fi
        else
            detected_env="offline_ubuntu"  # 默认
        fi
    fi
    
    write_status "检测到的环境: $detected_env" "INFO"
    
    if [[ -n "$ENVIRONMENT" && "$ENVIRONMENT" != "$detected_env" ]]; then
        write_status "指定环境与检测环境不匹配: $ENVIRONMENT vs $detected_env" "WARNING"
    fi
    
    echo "$detected_env"
}

# 测试路径访问
test_path_access() {
    local path="$1"
    local path_name="$2"
    
    if [[ -z "$path" ]]; then
        write_status "路径配置 '$path_name' 为空" "WARNING"
        return 1
    fi
    
    if [[ ! -d "$path" ]]; then
        write_status "路径不存在: $path" "WARNING"
        return 1
    fi
    
    # 测试写入权限
    local test_file="$path/test-access.tmp"
    if touch "$test_file" 2>/dev/null; then
        rm -f "$test_file"
        write_status "路径可访问: $path" "OK"
        return 0
    else
        write_status "路径无写入权限: $path" "ERROR"
        return 1
    fi
}

# 测试Git配置
test_git_config() {
    local user_name="$1"
    local user_email="$2"
    local is_valid=true
    
    if [[ -z "$user_name" || "$user_name" == "Your Name" ]]; then
        write_status "Git用户名未设置或使用默认值" "WARNING"
        is_valid=false
    else
        write_status "Git用户名: $user_name" "OK"
    fi
    
    if [[ -z "$user_email" || "$user_email" == "your.email@company.com" ]]; then
        write_status "Git邮箱未设置或使用默认值" "WARNING"
        is_valid=false
    else
        write_status "Git邮箱: $user_email" "OK"
    fi
    
    [[ "$is_valid" == "true" ]]
}

# 测试Git安装
test_git_installation() {
    if command -v git &> /dev/null; then
        local git_version=$(git --version 2>/dev/null)
        write_status "Git已安装: $git_version" "OK"
        return 0
    else
        write_status "Git未安装或不在PATH中" "ERROR"
        return 1
    fi
}

# 读取JSON配置
read_json_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        write_status "配置文件不存在: $CONFIG_FILE" "ERROR"
        return 1
    fi
    
    if ! command -v jq &> /dev/null; then
        write_status "jq未安装，无法解析JSON配置" "ERROR"
        return 1
    fi
    
    if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
        write_status "配置文件格式错误" "ERROR"
        return 1
    fi
    
    write_status "配置文件读取成功" "OK"
    return 0
}

# 获取环境配置
get_environment_config() {
    local env_name="$1"
    
    if ! jq -e ".environments.$env_name" "$CONFIG_FILE" >/dev/null 2>&1; then
        write_status "环境配置 '$env_name' 不存在" "ERROR"
        return 1
    fi
    
    write_status "环境配置加载成功" "OK"
    return 0
}

# 测试路径配置
test_path_config() {
    local env_name="$1"
    local path_success=true
    
    write_status "测试路径配置..." "INFO"
    
    # 检查路径配置是否存在
    if ! jq -e ".environments.$env_name.paths" "$CONFIG_FILE" >/dev/null 2>&1; then
        write_status "路径配置缺失" "ERROR"
        return 1
    fi
    
    # 测试每个路径
    local paths=$(jq -r ".environments.$env_name.paths | to_entries[] | .key + \"|\" + .value" "$CONFIG_FILE" 2>/dev/null)
    
    while IFS='|' read -r key value; do
        if [[ -n "$key" && -n "$value" ]]; then
            if ! test_path_access "$value" "$key"; then
                path_success=false
            fi
        fi
    done <<< "$paths"
    
    [[ "$path_success" == "true" ]]
}

# 测试Git配置
test_git_config_section() {
    local env_name="$1"
    local git_success=true
    
    write_status "测试Git配置..." "INFO"
    
    if ! jq -e ".environments.$env_name.git" "$CONFIG_FILE" >/dev/null 2>&1; then
        write_status "Git配置缺失" "ERROR"
        return 1
    fi
    
    local user_name=$(jq -r ".environments.$env_name.git.user_name // empty" "$CONFIG_FILE" 2>/dev/null)
    local user_email=$(jq -r ".environments.$env_name.git.user_email // empty" "$CONFIG_FILE" 2>/dev/null)
    
    if ! test_git_config "$user_name" "$user_email"; then
        git_success=false
    fi
    
    [[ "$git_success" == "true" ]]
}

# 测试同步配置
test_sync_config() {
    local env_name="$1"
    
    write_status "测试同步配置..." "INFO"
    
    if jq -e ".environments.$env_name.sync" "$CONFIG_FILE" >/dev/null 2>&1; then
        write_status "同步配置存在" "OK"
        local sync_configs=$(jq -r ".environments.$env_name.sync | to_entries[] | .key + \": \" + (.value | tostring)" "$CONFIG_FILE" 2>/dev/null)
        while IFS=': ' read -r key value; do
            if [[ -n "$key" && -n "$value" ]]; then
                write_status "  $key: $value" "INFO"
            fi
        done <<< "$sync_configs"
        return 0
    else
        write_status "同步配置缺失" "WARNING"
        return 1
    fi
}

# 测试全局配置
test_global_config() {
    write_status "测试全局配置..." "INFO"
    
    if jq -e ".global" "$CONFIG_FILE" >/dev/null 2>&1; then
        write_status "全局配置存在" "OK"
        return 0
    else
        write_status "全局配置缺失" "ERROR"
        return 1
    fi
}

# 主测试函数
start_config_test() {
    echo -e "${CYAN}=== Git离线开发工具套件 - 配置测试 ===${NC}"
    echo ""
    
    local overall_success=true
    local test_results=()
    
    # 1. 测试配置文件读取
    write_status "开始配置测试..." "INFO"
    echo ""
    
    if ! read_json_config; then
        overall_success=false
        test_results+=("ConfigRead=false")
    else
        test_results+=("ConfigRead=true")
    fi
    
    # 2. 测试环境检测
    local detected_env=$(detect_environment)
    test_results+=("EnvironmentDetection=true")
    
    # 3. 测试Git安装
    if test_git_installation; then
        test_results+=("GitInstallation=true")
    else
        test_results+=("GitInstallation=false")
        overall_success=false
    fi
    
    # 4. 获取环境配置
    if get_environment_config "$detected_env"; then
        test_results+=("EnvironmentConfig=true")
        
        # 5. 测试路径配置
        if test_path_config "$detected_env"; then
            test_results+=("PathConfig=true")
        else
            test_results+=("PathConfig=false")
            overall_success=false
        fi
        
        # 6. 测试Git配置
        if test_git_config_section "$detected_env"; then
            test_results+=("GitConfig=true")
        else
            test_results+=("GitConfig=false")
            overall_success=false
        fi
        
        # 7. 测试同步配置
        if test_sync_config "$detected_env"; then
            test_results+=("SyncConfig=true")
        else
            test_results+=("SyncConfig=false")
        fi
    else
        test_results+=("EnvironmentConfig=false")
        overall_success=false
    fi
    
    # 8. 测试全局配置
    if test_global_config; then
        test_results+=("GlobalConfig=true")
    else
        test_results+=("GlobalConfig=false")
        overall_success=false
    fi
    
    # 显示测试总结
    echo ""
    echo -e "${CYAN}=== 测试总结 ===${NC}"
    
    local passed_tests=0
    local total_tests=${#test_results[@]}
    
    for result in "${test_results[@]}"; do
        if [[ "$result" == *"=true" ]]; then
            ((passed_tests++))
        fi
    done
    
    write_status "通过测试: $passed_tests/$total_tests" "INFO"
    
    if [[ "$overall_success" == "true" ]]; then
        write_status "配置测试通过！可以开始使用Git离线开发工具套件" "OK"
        echo ""
        echo -e "${YELLOW}下一步操作:${NC}"
        echo -e "${WHITE}1. 运行对应的初始化脚本${NC}"
        echo -e "${WHITE}2. 开始离线开发工作${NC}"
    else
        write_status "配置测试失败，请修复上述问题后重试" "ERROR"
        echo ""
        echo -e "${YELLOW}修复建议:${NC}"
        echo -e "${WHITE}1. 检查配置文件格式是否正确${NC}"
        echo -e "${WHITE}2. 确保所有路径都存在且可访问${NC}"
        echo -e "${WHITE}3. 设置正确的Git用户名和邮箱${NC}"
        echo -e "${WHITE}4. 确保Git已正确安装${NC}"
    fi
    
    [[ "$overall_success" == "true" ]]
}

# 显示帮助信息
show_help() {
    echo "用法: $0 [环境名称]"
    echo ""
    echo "参数:"
    echo "  环境名称    可选，指定要测试的环境 (offline_windows, offline_ubuntu, gitlab_server)"
    echo ""
    echo "示例:"
    echo "  $0                    # 自动检测环境并测试"
    echo "  $0 offline_windows    # 测试Windows环境配置"
    echo "  $0 offline_ubuntu     # 测试Ubuntu环境配置"
    echo "  $0 gitlab_server      # 测试GitLab服务器环境配置"
    echo ""
    echo "环境变量:"
    echo "  CONFIG_FILE          配置文件路径 (默认: config.json)"
}

# 主程序
main() {
    # 检查帮助参数
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        show_help
        exit 0
    fi
    
    # 执行测试
    if start_config_test; then
        exit 0
    else
        exit 1
    fi
}

# 执行主程序
main "$@" 