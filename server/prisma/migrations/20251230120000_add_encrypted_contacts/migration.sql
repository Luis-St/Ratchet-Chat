-- AlterTable
ALTER TABLE "User" ADD COLUMN     "encrypted_contacts" TEXT,
ADD COLUMN     "encrypted_contacts_iv" TEXT;
