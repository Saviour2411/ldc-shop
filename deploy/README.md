# LDC Shop 生产部署

本目录保存生产部署脚本。生产环境使用 `_docker` 目录构建镜像，服务器运行目录固定为 `/root/proj/ldc-shop`。

## GitHub Secrets

仓库需要配置以下 Secrets：

- `DOCKERHUB_USERNAME`: Docker Hub 用户名
- `DOCKERHUB_TOKEN`: Docker Hub access token
- `SERVER_HOST`: `87.76.198.249`
- `SERVER_USER`: `root`
- `SERVER_SSH_KEY`: 可 SSH 到服务器的私钥

## 服务器环境文件

`/root/proj/ldc-shop/.env` 由服务器维护，CI 不会创建或覆盖它。至少需要：

```env
APP_URL=https://shop.saviour.cc.cd
NEXT_PUBLIC_APP_URL=https://shop.saviour.cc.cd
AUTH_TRUST_HOST=true
AUTH_SECRET=replace_with_random_secret
OAUTH_CLIENT_ID=replace_with_linux_do_client_id
OAUTH_CLIENT_SECRET=replace_with_linux_do_client_secret
MERCHANT_ID=replace_with_epay_merchant_id
MERCHANT_KEY=replace_with_epay_merchant_key
PAY_URL=https://credit.linux.do/epay/pay/submit.php
ADMIN_USERS=replace_with_admin_usernames
DATABASE_PATH=/app/data/ldc-shop.sqlite
```

## 发布流程

普通 push 不会部署。发布生产版本时打 `v*` tag：

```bash
git tag v1.0.0
git push origin v1.0.0
```

GitHub Actions 会构建并推送：

- `saviour2411/ldc-shop:latest`
- `saviour2411/ldc-shop:<tag>`
- `saviour2411/ldc-shop:<short-sha>`

随后自动 SSH 到服务器执行 `deploy/server-deploy.sh`，拉取 `latest` 并重启容器。
