A 和 B 的日常开发流程
步骤 A、B 共用：
git checkout develop
git pull origin develop      # 更新本地develop到远程最新

A 的工作流程（嵌入式）
# 切换到功能分支（第一次创建时）
git checkout -b feature/vendor-f develop

# 开发过程中，随时将 develop 的更新合并到自己分支，保持同步
git checkout feature/vendor-f
git merge develop

# 代码提交
git add .
git commit -m "feat: 完成协议适配功能"

# 推送功能分支到远程
git push origin feature/vendor-f




B 的工作流程(前端)
# 切换到功能分支（第一次创建时）
git checkout -b feature/ui-custom develop

# 开发过程中，将 develop 的最新代码合并到功能分支
git checkout feature/ui-custom
git merge develop

# 代码提交
git add .
git commit -m "feat: 完成自定义UI"

# 推送功能分支到远程
git push origin feature/ui-custom