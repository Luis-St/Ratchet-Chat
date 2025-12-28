-- AlterTable
ALTER TABLE "User" ADD COLUMN     "encrypted_block_list" TEXT,
ADD COLUMN     "encrypted_block_list_iv" TEXT;
