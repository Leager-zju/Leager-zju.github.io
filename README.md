# Leager / Field Notes

基于 Hugo 构建的个人知识库与作品集，记录 C++、系统、图形学、Unreal Engine 与游戏开发。

## 本地预览

安装 Hugo Extended 后，在仓库根目录执行：

```bash
hugo server --buildDrafts
```

建议按以下路径验收：

- `/`：首页、视觉系统和栏目入口
- `/notes/`：86 篇文章、关键词和分类筛选
- `/notes/games101note/`：公式、图片与长文排版
- `/notes/c-function/`：代码高亮、目录和图片
- `/projects/`、`/games/`：项目与游戏内容模型
- `/archive/`：时间归档
- `/lab/`：验收台

## 内容维护

- 新文章放在 `content/notes/<slug>/index.md`；图片和视频放在同一页面包目录。
- 新项目放在 `content/projects/`；新游戏放在 `content/games/`。
- 主导航定义于 `data/navigation.yaml`。
- 视觉样式定义于 `assets/css/site.css`。
- 页面布局定义于 `layouts/`。

## 构建与发布

```bash
hugo --minify
```

GitHub Actions 会在 `hexo` 分支推送时构建根目录 Hugo 站点并发布到 GitHub Pages。首次使用时，请在仓库的 Pages 设置中选择 **GitHub Actions** 作为发布源。
