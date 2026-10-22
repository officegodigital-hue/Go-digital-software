USE godigital_db;

-- Add assignment separately from the original creator.
-- Run only after checking that assigned_to does not already exist.
ALTER TABLE invoices
ADD COLUMN assigned_to INT NULL DEFAULT NULL;

-- Record every assignment change.
CREATE TABLE IF NOT EXISTS invoice_assignment_history (
    id INT AUTO_INCREMENT PRIMARY KEY,
    invoice_id INT NOT NULL,
    previous_assigned_to INT NULL,
    new_assigned_to INT NULL,
    changed_by INT NOT NULL,
    changed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_invoice_assignment_invoice (invoice_id),
    INDEX idx_invoice_assignment_changed_at (changed_at),

    CONSTRAINT fk_invoice_assignment_invoice
        FOREIGN KEY (invoice_id)
        REFERENCES invoices(id)
        ON DELETE CASCADE
);
