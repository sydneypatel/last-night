require('dotenv').config();
const express = require('express');
const cors = require('cors');

const authRoutes    = require('./routes/auth');
const groupRoutes   = require('./routes/groups');
const photoRoutes   = require('./routes/photos');
const libraryRoutes = require('./routes/library');
const userRoutes    = require('./routes/users');
const errorHandler  = require('./middleware/errorHandler');

const app = express();

app.use(cors());
app.use(express.json());

app.get('/health', (req, res) => res.json({ status: 'ok' }));

app.use('/auth',    authRoutes);
app.use('/groups',  groupRoutes);
app.use('/photos',  photoRoutes);
app.use('/library', libraryRoutes);
app.use('/users',   userRoutes);

app.use(errorHandler);

module.exports = app;