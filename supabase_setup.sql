-- Bookshelf Supabase 테이블 설정
-- Supabase SQL Editor에서 실행

-- 1. books 테이블
CREATE TABLE books (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  author TEXT NOT NULL,
  publisher TEXT NOT NULL,
  isbn TEXT DEFAULT '',
  thumbnail_url TEXT DEFAULT '',
  description TEXT DEFAULT '',
  status INT DEFAULT 0,        -- 0: wantToRead, 1: reading, 2: finished, 3: dropped
  rating INT,
  memo TEXT DEFAULT '',
  added_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  started_at TIMESTAMPTZ,
  finished_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. 인덱스
CREATE INDEX idx_books_user_id ON books(user_id);
CREATE INDEX idx_books_user_status ON books(user_id, status);
CREATE INDEX idx_books_user_isbn ON books(user_id, isbn);

-- 3. updated_at 자동 갱신 트리거
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER books_updated_at
  BEFORE UPDATE ON books
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

-- 4. RLS (Row Level Security) 정책
ALTER TABLE books ENABLE ROW LEVEL SECURITY;

-- 자기 데이터만 읽기
CREATE POLICY "Users can read own books"
  ON books FOR SELECT
  USING (auth.uid() = user_id);

-- 자기 데이터만 쓰기
CREATE POLICY "Users can insert own books"
  ON books FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- 자기 데이터만 수정
CREATE POLICY "Users can update own books"
  ON books FOR UPDATE
  USING (auth.uid() = user_id);

-- 자기 데이터만 삭제
CREATE POLICY "Users can delete own books"
  ON books FOR DELETE
  USING (auth.uid() = user_id);
