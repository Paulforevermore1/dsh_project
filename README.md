# dsh_project

个人工作区集合仓库。主要项目以 git submodule 形式组织。

## 子模块

| 路径 | 仓库 |
| ---- | ---- |
| `Test/dsh-usage` | [Aisland-SJL/dsh-usage](https://github.com/Aisland-SJL/dsh-usage) |
| `Test/StarMap` | [Aisland-SJL/StarMap](https://github.com/Aisland-SJL/StarMap) |

## 克隆

```sh
git clone --recurse-submodules https://github.com/Paulforevermore1/dsh_project.git
```

若已克隆但未拉取子模块：

```sh
git submodule update --init --recursive
```

## 目录

- `translate/` — 翻译项目（文档 / agent 约定）
- `Test/` — 各类测试项目（子模块）
- `create-github-repo.ps1` / `create-github-repo.sh` — 创建 GitHub 仓库的向导脚本
