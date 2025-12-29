/*
  Warnings:

  - You are about to drop the column `event_type` on the `IncomingQueue` table. All the data in the column will be lost.
  - You are about to drop the column `reaction_emoji` on the `IncomingQueue` table. All the data in the column will be lost.

*/
-- DropIndex
DROP INDEX "IncomingQueue_recipient_id_message_id_event_type_sender_han_idx";

-- AlterTable
ALTER TABLE "IncomingQueue" DROP COLUMN "event_type",
DROP COLUMN "reaction_emoji";

-- CreateIndex
CREATE INDEX "IncomingQueue_recipient_id_sender_handle_idx" ON "IncomingQueue"("recipient_id", "sender_handle");
