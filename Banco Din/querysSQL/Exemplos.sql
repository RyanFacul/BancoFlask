USE banco;

-- Inserindo clientes com CPF e senha fictícios
INSERT INTO cliente (nomeCliente, cpfCliente, dataNiver, enderecoCliente, emailCliente, senha) 
VALUES 
    ('João Silva', '12345678901', '1980-05-12', 'Rua das Flores, 123', 'joao.silva@example.com', 'senha123'),
    ('Maria Oliveira', '23456789012', '1992-07-23', 'Av. Paulista, 456', 'maria.oliveira@example.com', 'senha123'),
    ('Carlos Souza', '34567890123', '1985-09-15', 'Rua da Paz, 789', 'carlos.souza@example.com', 'senha123');

-- Inserindo contas para os clientes
INSERT INTO conta (cliente_idCliente, agenciaConta, saldoConta, emprestimoConta, emprestimoRetirado)
VALUES 
    (1, '0001', 5000.00, 10000.00, 0.00), -- Conta de João Silva
    (2, '0002', 3000.00, 8000.00, 0.00),  -- Conta de Maria Oliveira
    (3, '0003', 7000.00, 15000.00, 0.00); -- Conta de Carlos Souza

-- Inserindo cartões de crédito para os clientes
INSERT INTO cartaCredito (conta_numeroConta, conta_cliente_idCliente, creditoDisponivel, creditoRetirado, nmrCartao, nmrSeguranca)
VALUES 
    (1, 1, 2000.00, 0.00, '1234567812345678', '123'), -- Cartão para João Silva
    (2, 2, 1500.00, 0.00, '2345678923456789', '234'), -- Cartão para Maria Oliveira
    (3, 3, 2500.00, 0.00, '3456789034567890', '345'); -- Cartão para Carlos Souza

-- Inserindo registros de extrato para os clientes
INSERT INTO extrato (valorExtrato, descricaoExtrato, conta_numeroConta, conta_cliente_idCliente)
VALUES 
    (1000.00, 'Depósito Inicial', 1, 1), -- Extrato para João Silva
    (-500.00, 'Saque', 1, 1),
    (2000.00, 'Depósito Inicial', 2, 2), -- Extrato para Maria Oliveira
    (-300.00, 'Saque', 2, 2),
    (500.00, 'Depósito Inicial', 3, 3), -- Extrato para Carlos Souza
    (-200.00, 'Saque', 3, 3);

-- Verificando clientes
SELECT * FROM cliente;

-- Verificando contas
SELECT * FROM conta;

-- Verificando cartões de crédito
SELECT * FROM cartaCredito;

-- Verificando extratos
SELECT * FROM extrato;
