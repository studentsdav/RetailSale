exports.getNotes = async (req, res) => {
    try {
        const outlet_id = req.user?.outlet_id || 0;
        const search = req.query.q || '';
        const section = req.query.section || 'notes'; // notes, archive, trash

        let whereClause = `outlet_id = :outlet_id`;
        if (section === 'archive') {
            whereClause += ` AND is_archived = true AND (is_trashed = false OR is_trashed IS NULL)`;
        } else if (section === 'trash') {
            whereClause += ` AND is_trashed = true`;
        } else {
            // Default active notes
            whereClause += ` AND (is_archived = false OR is_archived IS NULL) AND (is_trashed = false OR is_trashed IS NULL)`;
        }

        if (search.trim().length > 0) {
            whereClause += ` AND (title ILIKE :search OR content ILIKE :search)`;
        }

        const notes = await req.propertyDb.query(
            `SELECT * FROM user_notes WHERE ${whereClause} ORDER BY is_pinned DESC, id DESC`,
            {
                replacements: { outlet_id, search: `%${search.trim()}%` },
                type: req.propertyDb.QueryTypes.SELECT
            }
        );

        res.json({ success: true, data: notes });
    } catch (err) {
        console.error('[USER NOTES CONTROLLER GET ERROR]:', err);
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.createNote = async (req, res) => {
    try {
        const outlet_id = req.user?.outlet_id || 0;
        const user_id = req.user?.id || 1;

        const {
            title,
            content,
            color_hex,
            is_pinned,
            reminder_type,
            reminder_date,
            reminder_time
        } = req.body;

        const noteTitle = (title && title.trim().length > 0) ? title.trim() : 'New Note';
        const noteContent = content ? content.trim() : '';

        const [insertedRows] = await req.propertyDb.query(`
            INSERT INTO user_notes (outlet_id, user_id, title, content, color_hex, is_pinned, is_completed, is_archived, is_trashed, reminder_type, reminder_date, reminder_time, "createdAt", "updatedAt")
            VALUES (:outlet_id, :user_id, :title, :content, :color_hex, :is_pinned, false, false, false, :reminder_type, :reminder_date, :reminder_time, NOW(), NOW())
            RETURNING *
        `, {
            replacements: {
                outlet_id,
                user_id,
                title: noteTitle,
                content: noteContent,
                color_hex: color_hex || '#FEF08A',
                is_pinned: Boolean(is_pinned),
                reminder_type: reminder_type || 'NONE',
                reminder_date: reminder_date ? reminder_date : null,
                reminder_time: reminder_time || null
            },
            type: req.propertyDb.QueryTypes.INSERT
        });

        const newNote = insertedRows && insertedRows[0] ? insertedRows[0] : insertedRows;
        res.status(201).json({ success: true, data: newNote, message: 'Sticky Note created successfully.' });
    } catch (err) {
        console.error('[USER NOTES CREATE ERROR]:', err);
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.copyNote = async (req, res) => {
    try {
        const outlet_id = req.user?.outlet_id || 0;
        const user_id = req.user?.id || 1;
        const id = Number(req.params.id);

        const [existing] = await req.propertyDb.query(`SELECT * FROM user_notes WHERE id = :id AND outlet_id = :outlet_id`, {
            replacements: { id, outlet_id },
            type: req.propertyDb.QueryTypes.SELECT
        });

        if (!existing) {
            return res.status(404).json({ success: false, message: 'Source note not found.' });
        }

        const copyTitle = existing.title ? `${existing.title} (Copy)` : 'New Note Copy';

        const [insertedRows] = await req.propertyDb.query(`
            INSERT INTO user_notes (outlet_id, user_id, title, content, color_hex, is_pinned, is_completed, is_archived, is_trashed, reminder_type, reminder_date, reminder_time, "createdAt", "updatedAt")
            VALUES (:outlet_id, :user_id, :title, :content, :color_hex, :is_pinned, false, false, false, :reminder_type, :reminder_date, :reminder_time, NOW(), NOW())
            RETURNING *
        `, {
            replacements: {
                outlet_id,
                user_id,
                title: copyTitle,
                content: existing.content || '',
                color_hex: existing.color_hex || '#FEF08A',
                is_pinned: Boolean(existing.is_pinned),
                reminder_type: existing.reminder_type || 'NONE',
                reminder_date: existing.reminder_date ? existing.reminder_date : null,
                reminder_time: existing.reminder_time || null
            },
            type: req.propertyDb.QueryTypes.INSERT
        });

        const copiedNote = insertedRows && insertedRows[0] ? insertedRows[0] : insertedRows;
        res.status(201).json({ success: true, data: copiedNote, message: 'Note duplicated successfully.' });
    } catch (err) {
        console.error('[USER NOTES COPY ERROR]:', err);
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.updateNote = async (req, res) => {
    try {
        const outlet_id = req.user?.outlet_id || 0;
        const id = Number(req.params.id);

        const {
            title,
            content,
            color_hex,
            is_pinned,
            is_completed,
            is_archived,
            is_trashed,
            reminder_type,
            reminder_date,
            reminder_time
        } = req.body;

        const [updatedRows] = await req.propertyDb.query(`
            UPDATE user_notes
            SET title = COALESCE(:title, title),
                content = COALESCE(:content, content),
                color_hex = COALESCE(:color_hex, color_hex),
                is_pinned = COALESCE(:is_pinned, is_pinned),
                is_completed = COALESCE(:is_completed, is_completed),
                is_archived = COALESCE(:is_archived, is_archived),
                is_trashed = COALESCE(:is_trashed, is_trashed),
                reminder_type = COALESCE(:reminder_type, reminder_type),
                reminder_date = CASE WHEN :has_reminder_date THEN :reminder_date ELSE reminder_date END,
                reminder_time = COALESCE(:reminder_time, reminder_time),
                "updatedAt" = NOW()
            WHERE id = :id AND outlet_id = :outlet_id
            RETURNING *
        `, {
            replacements: {
                id,
                outlet_id,
                title: title !== undefined ? title : null,
                content: content !== undefined ? content : null,
                color_hex: color_hex !== undefined ? color_hex : null,
                is_pinned: is_pinned !== undefined ? Boolean(is_pinned) : null,
                is_completed: is_completed !== undefined ? Boolean(is_completed) : null,
                is_archived: is_archived !== undefined ? Boolean(is_archived) : null,
                is_trashed: is_trashed !== undefined ? Boolean(is_trashed) : null,
                reminder_type: reminder_type !== undefined ? reminder_type : null,
                has_reminder_date: reminder_date !== undefined,
                reminder_date: reminder_date ? reminder_date : null,
                reminder_time: reminder_time !== undefined ? reminder_time : null
            },
            type: req.propertyDb.QueryTypes.UPDATE
        });

        const note = updatedRows && updatedRows[0] ? updatedRows[0] : updatedRows;
        res.json({ success: true, data: note, message: 'Sticky Note updated.' });
    } catch (err) {
        console.error('[USER NOTES UPDATE ERROR]:', err);
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.toggleArchive = async (req, res) => {
    try {
        const outlet_id = req.user?.outlet_id || 0;
        const id = Number(req.params.id);

        const [updatedRows] = await req.propertyDb.query(`
            UPDATE user_notes
            SET is_archived = NOT COALESCE(is_archived, false),
                "updatedAt" = NOW()
            WHERE id = :id AND outlet_id = :outlet_id
            RETURNING *
        `, {
            replacements: { id, outlet_id },
            type: req.propertyDb.QueryTypes.UPDATE
        });

        const note = updatedRows && updatedRows[0] ? updatedRows[0] : updatedRows;
        res.json({ success: true, data: note });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.moveToTrash = async (req, res) => {
    try {
        const outlet_id = req.user?.outlet_id || 0;
        const id = Number(req.params.id);

        const [updatedRows] = await req.propertyDb.query(`
            UPDATE user_notes
            SET is_trashed = true,
                deleted_at = NOW(),
                "updatedAt" = NOW()
            WHERE id = :id AND outlet_id = :outlet_id
            RETURNING *
        `, {
            replacements: { id, outlet_id },
            type: req.propertyDb.QueryTypes.UPDATE
        });

        const note = updatedRows && updatedRows[0] ? updatedRows[0] : updatedRows;
        res.json({ success: true, data: note, message: 'Moved to Trash.' });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.restoreNote = async (req, res) => {
    try {
        const outlet_id = req.user?.outlet_id || 0;
        const id = Number(req.params.id);

        const [updatedRows] = await req.propertyDb.query(`
            UPDATE user_notes
            SET is_trashed = false,
                is_archived = false,
                deleted_at = NULL,
                "updatedAt" = NOW()
            WHERE id = :id AND outlet_id = :outlet_id
            RETURNING *
        `, {
            replacements: { id, outlet_id },
            type: req.propertyDb.QueryTypes.UPDATE
        });

        const note = updatedRows && updatedRows[0] ? updatedRows[0] : updatedRows;
        res.json({ success: true, data: note, message: 'Note restored.' });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.permanentDelete = async (req, res) => {
    try {
        const outlet_id = req.user?.outlet_id || 0;
        const id = Number(req.params.id);

        await req.propertyDb.query(`DELETE FROM user_notes WHERE id = :id AND outlet_id = :outlet_id`, {
            replacements: { id, outlet_id }
        });

        res.json({ success: true, message: 'Note deleted permanently.' });
    } catch (err) {
        console.error('[USER NOTES DELETE ERROR]:', err);
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.emptyTrash = async (req, res) => {
    try {
        const outlet_id = req.user?.outlet_id || 0;

        await req.propertyDb.query(`DELETE FROM user_notes WHERE is_trashed = true AND outlet_id = :outlet_id`, {
            replacements: { outlet_id }
        });

        res.json({ success: true, message: 'Trash emptied successfully.' });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};
