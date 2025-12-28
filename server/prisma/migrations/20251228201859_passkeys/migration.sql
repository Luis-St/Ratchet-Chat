/*
  Warnings:

  - You are about to drop the `Call` table. If the table is not empty, all the data it contains will be lost.

*/
-- DropForeignKey
ALTER TABLE "Call" DROP CONSTRAINT "Call_callee_id_fkey";

-- DropForeignKey
ALTER TABLE "Call" DROP CONSTRAINT "Call_caller_id_fkey";

-- DropTable
DROP TABLE "Call";

-- CreateTable
CREATE TABLE "PasskeyCredential" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "credential_id" TEXT NOT NULL,
    "public_key" BYTEA NOT NULL,
    "sign_count" INTEGER NOT NULL DEFAULT 0,
    "transports" TEXT[],
    "name" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "last_used_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PasskeyCredential_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "PasskeyCredential_credential_id_key" ON "PasskeyCredential"("credential_id");

-- CreateIndex
CREATE INDEX "PasskeyCredential_user_id_idx" ON "PasskeyCredential"("user_id");

-- AddForeignKey
ALTER TABLE "PasskeyCredential" ADD CONSTRAINT "PasskeyCredential_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
