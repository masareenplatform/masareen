// Social domain types for the MASAREEN social shell (feed, posts, messenger).

export type PostKind =
  | "story"
  | "program"
  | "task"
  | "evidence"
  | "impact"
  | "announcement"
  | "synergy"
  | "opportunity"
  | "recognition";

export interface PostMedia {
  url: string;
  type: "image" | "video";
  name?: string;
}

export interface PostComment {
  id: string;
  author: PostAuthor;
  text: string;
  createdAt: string;
}

export interface PostAuthor {
  id: string;
  name: string;
  handle: string;
  avatarUrl?: string;
  verified?: boolean;
  role?: string;
}

export interface Post {
  id: string;
  kind: PostKind;
  author: PostAuthor;
  text: string;
  media: PostMedia[];
  programTag?: string;
  sdg?: number;
  impactValue?: number;
  impactLabel?: string;
  likes: number;
  comments: PostComment[];
  shares: number;
  likedByMe: boolean;
  createdAt: string;
}

export interface ChatMessage {
  id: string;
  threadId: string;
  authorId: string;
  text: string;
  createdAt: string;
  seen?: boolean;
}

export interface ChatThread {
  id: string;
  peer: PostAuthor;
  messages: ChatMessage[];
  unread: number;
  lastActive: string;
}
