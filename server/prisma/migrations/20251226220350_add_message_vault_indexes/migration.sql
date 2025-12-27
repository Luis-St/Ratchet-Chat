-- CreateIndex
CREATE INDEX "MessageVault_owner_id_created_at_idx" ON "MessageVault"("owner_id", "created_at");

-- CreateIndex
CREATE INDEX "MessageVault_owner_id_id_idx" ON "MessageVault"("owner_id", "id");
