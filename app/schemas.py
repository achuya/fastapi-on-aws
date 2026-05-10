from pydantic import BaseModel, EmailStr
from datetime import datetime
from typing import Optional


# ===== User =====

class UserBase(BaseModel):
    name: str
    email: str


class UserCreate(UserBase):
    pass


class UserUpdate(BaseModel):
    name: Optional[str] = None
    email: Optional[str] = None


class PostSummary(BaseModel):
    id: int
    title: str
    created_at: datetime

    class Config:
        from_attributes = True


class UserResponse(UserBase):
    id: int
    created_at: datetime
    updated_at: datetime
    posts: list[PostSummary] = []

    class Config:
        from_attributes = True


# ===== Post =====

class PostBase(BaseModel):
    title: str
    content: Optional[str] = None


class PostCreate(PostBase):
    pass


class PostUpdate(BaseModel):
    title: Optional[str] = None
    content: Optional[str] = None


class PostResponse(PostBase):
    id: int
    user_id: int
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True