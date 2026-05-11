# FastAPI on AWS

ECS Fargate + RDS + ALB + CloudFrontを使ったREST API

## 構成

インターネット
↓
CloudFront
↓
ALB
↓
ECS Fargate（FastAPI）
↓
RDS MySQL

## 使用技術

- **言語**: Python 3.11
- **フレームワーク**: FastAPI
- **インフラ**: AWS（ECS Fargate / RDS / ALB / CloudFront）
- **IaC**: Terraform
- **CI/CD**: GitHub Actions

## API エンドポイント

### Users
| Method | Path | 説明 |
|--------|------|------|
| GET | /users/ | ユーザー一覧 |
| POST | /users/ | ユーザー作成 |
| GET | /users/{id} | ユーザー詳細 |
| PUT | /users/{id} | ユーザー更新 |
| DELETE | /users/{id} | ユーザー削除 |

### Posts
| Method | Path | 説明 |
|--------|------|------|
| GET | /users/{id}/posts | 投稿一覧 |
| POST | /users/{id}/posts | 投稿作成 |
| GET | /users/{id}/posts/{post_id} | 投稿詳細 |
| PUT | /users/{id}/posts/{post_id} | 投稿更新 |
| DELETE | /users/{id}/posts/{post_id} | 投稿削除 |

## ローカルでの起動方法

```bash
# 仮想環境の作成
python3 -m venv venv
source venv/bin/activate

# ライブラリのインストール
pip install -r requirements.txt

# 環境変数の設定
cp .env.example .env

# サーバーの起動
uvicorn app.main:app --reload --port 8000
```

## Swagger UI

http://localhost:8000/docs

## インフラの構築

```bash
cd infra
terraform init
terraform apply
```

## CI/CD

mainブランチへのpushで自動デプロイ：

git push origin main
↓
GitHub Actions
↓
Docker build → ECR push → ECSデプロイ