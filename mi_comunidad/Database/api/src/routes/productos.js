const { Router } = require('express');
const productos = require('../models/productos');

const router = Router();

router.get('/', async (_req, res, next) => {
  try {
    const rows = await productos.list();
    res.json({ count: rows.length, data: rows });
  } catch (err) {
    next(err);
  }
});

router.get('/:id', async (req, res, next) => {
  try {
    const row = await productos.findById(req.params.id);
    if (!row) {
      return res.status(404).json({ error: 'Producto no encontrado' });
    }
    res.json({ data: row });
  } catch (err) {
    next(err);
  }
});

router.post('/', async (req, res, next) => {
  try {
    const { nombre, precio, stock } = req.body;
    if (!nombre || precio === undefined) {
      return res.status(400).json({
        error: 'Campos requeridos: nombre (string) y precio (number)',
      });
    }
    if (typeof nombre !== 'string' || Number.isNaN(Number(precio)) || Number(precio) < 0) {
      return res.status(400).json({ error: 'Valores invalidos para nombre o precio' });
    }
    const row = await productos.create({ nombre, precio: Number(precio), stock });
    res.status(201).json({ data: row });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
