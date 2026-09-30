const router = require('express').Router();
const auth = require('../middlewares/auth.middleware');
const notesCtrl = require('../controllers/notes/userNote.controller');

router.use(auth);

router.get('/', notesCtrl.getNotes);
router.post('/', notesCtrl.createNote);
router.post('/:id/copy', notesCtrl.copyNote);
router.put('/:id', notesCtrl.updateNote);
router.put('/:id/archive', notesCtrl.toggleArchive);
router.put('/:id/trash', notesCtrl.moveToTrash);
router.put('/:id/restore', notesCtrl.restoreNote);
router.delete('/:id/permanent', notesCtrl.permanentDelete);
router.delete('/trash/empty', notesCtrl.emptyTrash);

module.exports = router;
