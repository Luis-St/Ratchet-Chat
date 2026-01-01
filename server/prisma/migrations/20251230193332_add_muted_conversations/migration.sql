-- AlterTable
ALTER TABLE "User" ADD COLUMN     "encrypted_muted_conversations" TEXT,
ADD COLUMN     "encrypted_muted_conversations_iv" TEXT;
