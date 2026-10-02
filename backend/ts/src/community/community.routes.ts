import { Router } from 'express';
import { CommunityController } from './community.controller';

const router = Router();
const controller = new CommunityController();

router.get('/conversations', (req, res) => controller.getConversations(req, res));
router.get('/messages', (req, res) => controller.getMessages(req, res));
router.post('/messages', (req, res) => controller.sendMessage(req, res));
router.post('/messages/delete-for-everyone', (req, res) => controller.deleteForEveryone(req, res));
router.post('/messages/delete-for-me', (req, res) => controller.deleteForMe(req, res));

export default router;
