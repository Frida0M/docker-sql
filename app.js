const express = require('express');
const app = express();
const mysql = require('mysql2');

app.get('/', (req, res) => {
    res.send('Servidor de la aplicación.');
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`Servidor escuchando en el puerto ${PORT}`);
});


const db = mysql.createConnection({
    host: 'docker-sql-mysql-container-1',
    user: 'admin',
    password: 'password',
    database: 'mydb',
    allowPublicKeyRetrieval: true
});

db.connect((err) => {
    if (err) {
        console.error('Error al conectar a MySQL:', err);
    } else {
        console.log('Conexión exitosa a MySQL');
    }
});