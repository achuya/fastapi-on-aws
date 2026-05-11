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


## 環境の再構築手順

### 1. インフラの構築

```bash
cd infra
terraform init
terraform apply
```

### 2. ECRへのDockerイメージのpush

```bash
# AWSのECRにログイン
aws ecr get-login-password --region ap-northeast-1 | \
  docker login --username AWS --password-stdin \
  058898200941.dkr.ecr.ap-northeast-1.amazonaws.com

# イメージをビルドしてpush
docker buildx build \
  --platform linux/amd64 \
  -t 058898200941.dkr.ecr.ap-northeast-1.amazonaws.com/fastapi-app:latest \
  --push \
  .
```

### 3. ECSサービスを更新

```bash
aws ecs update-service \
  --cluster fastapi-cluster \
  --service fastapi-service \
  --force-new-deployment \
  --region ap-northeast-1
```

### 4. 踏み台サーバーでRDSにmigration

```bash
# 踏み台サーバーにSSH接続
ssh -i ~/.ssh/id_rsa ec2-user@<bastion_public_ip>

# 必要なパッケージをインストール
sudo yum install -y python3 python3-pip
pip3 install sqlalchemy pymysql alembic cryptography

# migrationを実行
python3 << 'EOF'
from sqlalchemy import create_engine, Column, Integer, String, Text, DateTime, ForeignKey
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

DATABASE_URL = "mysql+pymysql://admin:Password1234!@<rds_endpoint>:3306/fastapidb"

engine = create_engine(DATABASE_URL)
Base = declarative_base()

class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), nullable=False)
    email = Column(String(255), unique=True, nullable=False, index=True)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())
    posts = relationship("Post", back_populates="user", cascade="all, delete")

class Post(Base):
    __tablename__ = "posts"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    title = Column(String(255), nullable=False)
    content = Column(Text, nullable=True)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())
    user = relationship("User", back_populates="posts")

Base.metadata.create_all(bind=engine)
print("Migration completed!")
EOF
```

### 5. 環境の削除

```bash
cd infra
terraform destroy
```

> ⚠️ NAT Gatewayは課金が続くので使い終わったら必ずdestroyしましょう！

### 出力値の確認

```bash
cd infra
terraform output
```

```
alb_dns_name       = "xxx.ap-northeast-1.elb.amazonaws.com"
bastion_public_ip  = "xx.xx.xx.xx"
cloudfront_url     = "https://xxx.cloudfront.net"
ecr_repository_url = "xxx.dkr.ecr.ap-northeast-1.amazonaws.com/fastapi-app"
rds_endpoint       = "xxx.ap-northeast-1.rds.amazonaws.com"
```


## 環境の削除手順

### 1. ECRのイメージを削除

```bash
aws ecr delete-repository \
  --repository-name fastapi-app \
  --region ap-northeast-1 \
  --force
```

### 2. インフラを削除

```bash
cd infra
terraform destroy
```

> ⚠️ destroyの前にECRのイメージを削除しないとエラーになります！
> 必ず上記の順番で実行してください。