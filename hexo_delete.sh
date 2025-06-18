#!/bin/bash

# Hexo 文章删除助手
# 功能：删除指定文章及其关联资源文件夹
# 使用方法：将脚本放在 Hexo 根目录执行，或指定文章路径

# 设置 Hexo 项目路径（默认为当前目录）
HEXO_DIR=$(pwd)

# 检查是否在 Hexo 项目目录
if [ ! -f "${HEXO_DIR}/_config.yml" ]; then
  echo "❌ 错误：当前目录不是 Hexo 项目根目录"
  echo "请进入 Hexo 项目目录或指定路径"
  exit 1
fi

# 文章目录和资源目录设置
POSTS_DIR="${HEXO_DIR}/source/_posts"
ASSETS_DIR="${POSTS_DIR}"  # 资源文件夹通常与文章同目录

# 显示帮助信息
show_help() {
  echo "使用说明:"
  echo "  $0 [文章文件名]"
  echo "  $0 -i (交互模式)"
  echo "示例:"
  echo "  $0 my-post.md"
  echo "  $0 '含有空格的文章.md'"
}

# 删除文章及资源
delete_post() {
  local post_file=$1

  if [[ "$post_file" != *.md ]]; then
    post_file="$post_file.md"
  fi

  local post_name=$(basename "${post_file}" .md)
  local asset_dir="${ASSETS_DIR}/${post_name}"

  # 检查文章是否存在
  if [ ! -f "${post_file}" ]; then
    echo "❌ 错误：文章不存在 - ${post_file}"
    return 1
  fi

  echo "➡️ 正在删除文章: ${post_file}"
  rm -f "${post_file}"

  # 删除关联资源文件夹
  if [ -d "${asset_dir}" ]; then
    echo "➡️ 正在删除资源文件夹: ${asset_dir}"
    rm -rf "${asset_dir}"
  else
    echo "ℹ️ 未找到关联资源文件夹: ${asset_dir}"
  fi

  # 重新生成博客
  echo "🔄 清理缓存并重新生成博客..."
  echo "\n✅ 已完成删除操作！"
}

# 交互模式
interactive_mode() {
  echo "\n📝 可删除的文章列表："
  ls "${POSTS_DIR}" | grep '.md$'

  echo "\n请输入要删除的文章文件名（支持 Tab 补全）："
  read -p "> " post_file

  if [ -z "${post_file}" ]; then
    echo "操作已取消"
    exit 0
  fi

  # 确保文件在文章目录
  if [[ "${post_file}" != *".md" ]]; then
    post_file="${post_file}.md"
  fi

  full_path="${POSTS_DIR}/${post_file}"
  delete_post "${full_path}"
}

# 主程序
if [ $# -eq 0 ]; then
  show_help
  exit 0
fi

case $1 in
  -h|--help)
    show_help
    ;;
  -i|--interactive)
    interactive_mode
    ;;
  *)
    # 处理带路径的文件名
    if [[ "$1" == *"/"* ]]; then
      target_file="$1"
    else
      target_file="${POSTS_DIR}/$1"
    fi
    delete_post "${target_file}"
    ;;
esac