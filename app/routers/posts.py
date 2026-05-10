from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app import models, schemas
from app.database import get_db

router = APIRouter(
    prefix="/users",
    tags=["posts"]
)


@router.get("/{user_id}/posts", response_model=list[schemas.PostResponse])
def get_posts(user_id: int, db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    posts = db.query(models.Post).filter(models.Post.user_id == user_id).all()
    return posts


@router.get("/{user_id}/posts/{post_id}", response_model=schemas.PostResponse)
def get_post(user_id: int, post_id: int, db: Session = Depends(get_db)):
    post = db.query(models.Post).filter(
        models.Post.id == post_id,
        models.Post.user_id == user_id
    ).first()
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")
    return post


@router.post("/{user_id}/posts", response_model=schemas.PostResponse, status_code=201)
def create_post(user_id: int, post: schemas.PostCreate, db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    db_post = models.Post(
        user_id=user_id,
        title=post.title,
        content=post.content
    )
    db.add(db_post)
    db.commit()
    db.refresh(db_post)
    return db_post


@router.put("/{user_id}/posts/{post_id}", response_model=schemas.PostResponse)
def update_post(
    user_id: int,
    post_id: int,
    post: schemas.PostUpdate,
    db: Session = Depends(get_db)
):
    db_post = db.query(models.Post).filter(
        models.Post.id == post_id,
        models.Post.user_id == user_id
    ).first()
    if not db_post:
        raise HTTPException(status_code=404, detail="Post not found")

    if post.title is not None:
        db_post.title = post.title
    if post.content is not None:
        db_post.content = post.content

    db.commit()
    db.refresh(db_post)
    return db_post


@router.delete("/{user_id}/posts/{post_id}", status_code=204)
def delete_post(user_id: int, post_id: int, db: Session = Depends(get_db)):
    db_post = db.query(models.Post).filter(
        models.Post.id == post_id,
        models.Post.user_id == user_id
    ).first()
    if not db_post:
        raise HTTPException(status_code=404, detail="Post not found")

    db.delete(db_post)
    db.commit()