use `banco`;

-- procedure para realização e autenticação do login
DELIMITER //
CREATE PROCEDURE login(IN cpfNmrCliente VARCHAR(11), IN senhaSenha VARCHAR(255))
BEGIN
    SELECT idCliente FROM cliente WHERE cpfCliente = cpfNmrCliente AND senha = senhaSenha;
END //
DELIMITER ;

-- procedure para coleta do nome do usuario
DELIMITER //
CREATE PROCEDURE pegaNome(IN nomeNome INT)
BEGIN
    SELECT nomeCliente FROM Cliente WHERE idCliente = nomeNome;
END //
DELIMITER ;

-- procedure para realização de deposita na conta do cliente
DELIMITER //
CREATE PROCEDURE deposito(IN p_numeroConta INT, IN p_clienteId INT, IN p_valor DECIMAL(14,2), IN p_descricao VARCHAR(40))
BEGIN
    -- Verifica se o valor do depósito é positivo
    IF p_valor > 0 THEN
        -- Atualiza o saldo da conta
        UPDATE conta
        SET saldoConta = saldoConta + p_valor
        WHERE numeroConta = p_numeroConta AND cliente_idCliente = p_clienteId;
        -- Insere a operação de depósito na tabela extrato
        INSERT INTO extrato (valorExtrato, descricaoExtrato, conta_numeroConta, conta_cliente_idCliente)
        VALUES (p_valor, IFNULL(p_descricao, 'Depósito'), p_numeroConta, p_clienteId);
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'O valor do depósito deve ser positivo';
    END IF;
END //
DELIMITER ;

-- procedure para realização de saque
DELIMITER //
CREATE PROCEDURE saque(IN p_numeroConta INT, IN p_clienteId INT, IN p_valor DECIMAL(14,2), IN p_descricao VARCHAR(40))
BEGIN
    -- Verifica se o valor do saque é positivo
    IF p_valor > 0 THEN
        -- Atualiza o saldo da conta
        UPDATE conta
        SET saldoConta = saldoConta - p_valor
        WHERE numeroConta = p_numeroConta AND cliente_idCliente = p_clienteId;
        -- Insere a operação de saque na tabela extrato
        INSERT INTO extrato (valorExtrato, descricaoExtrato, conta_numeroConta, conta_cliente_idCliente)
        VALUES (-p_valor, IFNULL(p_descricao, 'Saque'), p_numeroConta, p_clienteId);
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'O valor do saque deve ser positivo';
    END IF;
END //
DELIMITER ;

-- trigguer que impede negativar conta
DELIMITER //
CREATE TRIGGER verifica_saldo_suficiente
BEFORE UPDATE ON conta
FOR EACH ROW
BEGIN
    -- Verifica se a operação envolve uma redução do saldo (saque)
    IF NEW.saldoConta < OLD.saldoConta THEN
        -- Impede a operação se o saldo atual for insuficiente para o saque
        IF OLD.saldoConta < (OLD.saldoConta - NEW.saldoConta) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Saldo insuficiente para realizar o saque';
        END IF;
    END IF;
END //
DELIMITER ;

-- proocedure para transferencia entre contas
DELIMITER //
CREATE PROCEDURE transferencia(
    IN p_contaOrigem INT,
    IN p_contaDestino INT,
    IN p_clienteIdOrigem INT,
    IN p_valor DECIMAL(14,2),
    IN p_descricao VARCHAR(40)
)
BEGIN
    DECLARE v_saldoOrigem DECIMAL(14,2);
    DECLARE v_clienteIdDestino INT;

    -- Verifica se o valor da transferência é positivo
    IF p_valor > 0 THEN
        -- Obtém o saldo atual da conta de origem
        SELECT saldoConta INTO v_saldoOrigem
        FROM conta
        WHERE numeroConta = p_contaOrigem
          AND cliente_idCliente = p_clienteIdOrigem;

        -- Verifica se há saldo suficiente para a transferência
        IF v_saldoOrigem >= p_valor THEN
            -- Obtém o cliente_idCliente da conta de destino
            SELECT cliente_idCliente INTO v_clienteIdDestino
            FROM conta
            WHERE numeroConta = p_contaDestino;

            -- Inicia uma transação
            START TRANSACTION;

            -- Realiza o débito na conta de origem
            UPDATE conta
            SET saldoConta = saldoConta - p_valor
            WHERE numeroConta = p_contaOrigem
              AND cliente_idCliente = p_clienteIdOrigem;

            -- Realiza o crédito na conta de destino
            UPDATE conta
            SET saldoConta = saldoConta + p_valor
            WHERE numeroConta = p_contaDestino;

            -- Insere a operação de débito no extrato da conta de origem
            INSERT INTO extrato (valorExtrato, descricaoExtrato, conta_numeroConta, conta_cliente_idCliente)
            VALUES (-p_valor, IFNULL(p_descricao, 'Transferência enviada'), p_contaOrigem, p_clienteIdOrigem);

            -- Insere a operação de crédito no extrato da conta de destino
            INSERT INTO extrato (valorExtrato, descricaoExtrato, conta_numeroConta, conta_cliente_idCliente)
            VALUES (p_valor, IFNULL(p_descricao, 'Transferência recebida'), p_contaDestino, v_clienteIdDestino);

            -- Confirma a transação
            COMMIT;
        ELSE
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Erro ao realizar transação';
        END IF;
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'O valor da transferência deve ser positivo';
    END IF;
END //

DELIMITER ;

-- procedure para consulta de saldo
DELIMITER //
CREATE PROCEDURE verificar_saldo(
    IN p_contaNumero INT,
    IN p_clienteId INT
)
BEGIN
    -- Consulta os dados da conta
    SELECT 
        saldoConta, 
        emprestimoConta, 
        emprestimoRetirado
    FROM conta
    WHERE numeroConta = p_contaNumero
      AND cliente_idCliente = p_clienteId;
    
    -- Verifica se a consulta retornou algum resultado
    IF FOUND_ROWS() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Conta não encontrada ou o cliente não é o proprietário da conta';
    END IF;
END //
DELIMITER ;

-- procedure para solicitar credito para a conta atraves do cartao
DELIMITER //
CREATE PROCEDURE solicitar_credito(IN p_numeroConta INT,IN p_clienteId INT,IN p_nmrCartao VARCHAR(16),IN p_codigoSeguranca VARCHAR(3),IN p_valorSolicitado DECIMAL(14,2))
BEGIN
    DECLARE v_creditoDisponivel DECIMAL(14,2);
    DECLARE v_creditoRetirado DECIMAL(14,2);
    DECLARE v_novoCreditoRetirado DECIMAL(14,2);

    -- Verifica se o valor solicitado é positivo
    IF p_valorSolicitado > 0 THEN
        -- Obtém o limite de crédito disponível e o valor já retirado após validar o cartão e o código de segurança
        SELECT creditoDisponivel, creditoRetirado INTO v_creditoDisponivel, v_creditoRetirado
        FROM cartaCredito
        WHERE nmrCartao = p_nmrCartao AND nmrSeguranca = p_codigoSeguranca AND conta_numeroConta = p_numeroConta AND conta_cliente_idCliente = p_clienteId;

        -- Verifica se o cartão foi encontrado e os dados de segurança estão corretos
        IF FOUND_ROWS() = 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cartão não encontrado ou código de segurança incorreto';
        ELSE
            -- Calcula o novo total retirado após o crédito solicitado
            SET v_novoCreditoRetirado = v_creditoRetirado + p_valorSolicitado;

            -- Verifica se o novo valor retirado não excede o crédito disponível
            IF v_novoCreditoRetirado <= v_creditoDisponivel THEN
                -- Atualiza o saldo da conta, adicionando o valor solicitado
                UPDATE conta
                SET saldoConta = saldoConta + p_valorSolicitado
                WHERE numeroConta = p_numeroConta
                  AND cliente_idCliente = p_clienteId;

                -- Atualiza o valor retirado no cartão de crédito
                UPDATE cartaCredito
                SET creditoRetirado = v_novoCreditoRetirado
                WHERE nmrCartao = p_nmrCartao;

                -- Insere um registro no extrato
                INSERT INTO extrato (valorExtrato, descricaoExtrato, conta_numeroConta, conta_cliente_idCliente)
                VALUES (p_valorSolicitado, 'Retirada de crédito do cartão', p_numeroConta, p_clienteId);

                -- Confirma a operação
                COMMIT;
            ELSE
                -- Gera um erro se o valor solicitado exceder o crédito disponível
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Crédito insuficiente para o valor solicitado';
            END IF;
        END IF;
    ELSE
        -- Gera um erro se o valor solicitado for negativo ou zero
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'O valor solicitado deve ser positivo';
    END IF;
END //
DELIMITER ;

-- trigguer para evitar que seja tirado mais saldo do que disponivel no credito
DELIMITER //
CREATE TRIGGER verificar_limite_credito
BEFORE UPDATE ON cartaCredito
FOR EACH ROW
BEGIN
    -- Verifica se o crédito retirado excede o disponível após a operação
    IF NEW.creditoRetirado > NEW.creditoDisponivel THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Operação cancelada: Crédito retirado excede o limite disponível';
    END IF;
END //
DELIMITER ;

-- Verificar cartões disponiveis
DELIMITER //
CREATE PROCEDURE consultar_cartoes_cliente(
    IN p_clienteId INT
)
BEGIN
    -- Seleciona os dados dos cartões de crédito associados ao cliente e a agência correspondente
    SELECT 
        c.agenciaConta AS AgenciaConta,
        cc.nmrCartao AS NumeroCartao,
        cc.nmrSeguranca AS CodigoSeguranca,
        cc.creditoDisponivel AS CreditoDisponivel,
        cc.creditoRetirado AS CreditoRetirado
    FROM 
        cartaCredito cc
    INNER JOIN 
        conta c ON cc.conta_numeroConta = c.numeroConta
              AND cc.conta_cliente_idCliente = c.cliente_idCliente
    WHERE 
        c.cliente_idCliente = p_clienteId;
END //
DELIMITER ;;

-- procedure para pegar emprestimo
DELIMITER //
CREATE PROCEDURE solicitar_emprestimo(
    IN p_numeroConta INT,
    IN p_clienteId INT,
    IN p_valorSolicitado DECIMAL(14,2)
)
BEGIN
    DECLARE v_emprestimoDisponivel DECIMAL(14,2);
    DECLARE v_emprestimoRetirado DECIMAL(14,2);
    DECLARE v_novoEmprestimoRetirado DECIMAL(14,2);

    -- Verifica se o valor solicitado é positivo
    IF p_valorSolicitado > 0 THEN
        -- Obtém o limite de empréstimo disponível e o valor já retirado
        SELECT emprestimoConta, emprestimoRetirado INTO v_emprestimoDisponivel, v_emprestimoRetirado
        FROM conta
        WHERE numeroConta = p_numeroConta
          AND cliente_idCliente = p_clienteId;

        -- Calcula o novo total retirado após o empréstimo solicitado
        SET v_novoEmprestimoRetirado = v_emprestimoRetirado + p_valorSolicitado;

        -- Verifica se o novo valor retirado não excede o empréstimo disponível
        IF v_novoEmprestimoRetirado <= v_emprestimoDisponivel THEN
            -- Atualiza o saldo da conta, adicionando o valor do empréstimo
            UPDATE conta
            SET saldoConta = saldoConta + p_valorSolicitado,
                emprestimoRetirado = v_novoEmprestimoRetirado
            WHERE numeroConta = p_numeroConta
              AND cliente_idCliente = p_clienteId;

            -- Insere um registro no extrato
            INSERT INTO extrato (valorExtrato, descricaoExtrato, conta_numeroConta, conta_cliente_idCliente)
            VALUES (p_valorSolicitado, 'Solicitação de empréstimo', p_numeroConta, p_clienteId);

            -- Confirma a operação
            COMMIT;
        ELSE
            -- Gera um erro se o valor solicitado exceder o empréstimo disponível
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Erro ao realizar a operação';
        END IF;
    ELSE
        -- Gera um erro se o valor solicitado for negativo ou zero
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'O valor solicitado deve ser positivo';
    END IF;
END //
DELIMITER ;

-- trigguer para impedir retirada de emprestimo excedente
DELIMITER //
CREATE TRIGGER verificar_limite_emprestimo
BEFORE UPDATE ON conta
FOR EACH ROW
BEGIN
    -- Verifica se o novo valor retirado excede o empréstimo disponível
    IF NEW.emprestimoRetirado > NEW.emprestimoConta THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Erro ao realizar a operação';
    END IF;
END //
DELIMITER ;

-- Consulta extrato
DELIMITER //
CREATE PROCEDURE consultar_extrato(
    IN p_clienteId INT
)
BEGIN
    -- Seleciona as movimentações do extrato para o cliente, incluindo a agência associada à conta
    SELECT 
        e.valorExtrato AS Valor,
        e.descricaoExtrato AS Descricao,
        c.agenciaConta AS Agencia
    FROM 
        extrato e
    INNER JOIN 
        conta c ON e.conta_numeroConta = c.numeroConta
              AND e.conta_cliente_idCliente = c.cliente_idCliente
    WHERE 
        c.cliente_idCliente = p_clienteId;
END //
DELIMITER ;

-- procedure para pagamento do credito
DELIMITER //
CREATE PROCEDURE pagar_credito(
    IN p_numeroConta INT,
    IN p_clienteId INT,
    IN p_nmrCartao VARCHAR(16),
    IN p_nmrSeguranca VARCHAR(3),
    IN p_valorPagamento DECIMAL(14,2)
)
BEGIN
    DECLARE v_creditoRetirado DECIMAL(14,2);
    DECLARE v_saldoConta DECIMAL(14,2);
    DECLARE v_novoCreditoRetirado DECIMAL(14,2);
    DECLARE v_cartaoValido INT;

    -- Verifica se o valor de pagamento é positivo
    IF p_valorPagamento > 0 THEN
        -- Verifica se o número do cartão e o código de segurança são válidos
        SELECT COUNT(*) 
        INTO v_cartaoValido
        FROM cartaCredito
        WHERE nmrCartao = p_nmrCartao
          AND nmrSeguranca = p_nmrSeguranca
          AND conta_numeroConta = p_numeroConta
          AND conta_cliente_idCliente = p_clienteId;

        -- Se o cartão não for encontrado, exibe erro
        IF v_cartaoValido = 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cartão ou código de segurança inválidos.';
        ELSE
            -- Obtém o valor do crédito retirado e o saldo da conta
            SELECT creditoRetirado, saldoConta 
            INTO v_creditoRetirado, v_saldoConta
            FROM conta c
            INNER JOIN cartaCredito cc ON c.numeroConta = cc.conta_numeroConta
                                       AND c.cliente_idCliente = cc.conta_cliente_idCliente
            WHERE c.numeroConta = p_numeroConta
              AND c.cliente_idCliente = p_clienteId
              AND cc.nmrCartao = p_nmrCartao
              AND cc.nmrSeguranca = p_nmrSeguranca;

            -- Verifica se o valor de pagamento não é maior que o valor do crédito retirado
            IF p_valorPagamento > v_creditoRetirado THEN
                -- Se o pagamento for maior que o valor do crédito retirado, exibe erro
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'O valor do pagamento não pode ser maior que o crédito retirado.';
            ELSE
                -- Deduz o valor do pagamento do saldo da conta
                SET v_saldoConta = v_saldoConta - p_valorPagamento;

                -- Atualiza o valor do crédito retirado após o pagamento
                SET v_novoCreditoRetirado = v_creditoRetirado - p_valorPagamento;

                -- Atualiza o saldo da conta
                UPDATE conta
                SET saldoConta = v_saldoConta
                WHERE numeroConta = p_numeroConta
                  AND cliente_idCliente = p_clienteId;

                -- Atualiza o valor do crédito retirado na tabela cartão de crédito
                UPDATE cartaCredito
                SET creditoRetirado = v_novoCreditoRetirado
                WHERE nmrCartao = p_nmrCartao
                  AND nmrSeguranca = p_nmrSeguranca
                  AND conta_numeroConta = p_numeroConta
                  AND conta_cliente_idCliente = p_clienteId;

                -- Registra o pagamento no extrato
                INSERT INTO extrato (valorExtrato, descricaoExtrato, conta_numeroConta, conta_cliente_idCliente)
                VALUES (-p_valorPagamento, 'Pagamento de crédito no cartão', p_numeroConta, p_clienteId);

                -- Confirma a operação
                COMMIT;
            END IF;
        END IF;
    ELSE
        -- Exibe erro se o valor de pagamento for zero ou negativo
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'O valor do pagamento deve ser positivo';
    END IF;
END //
DELIMITER ;

-- procedure para pagamento do emprestimo
DELIMITER //

CREATE PROCEDURE pagar_emprestimo(
    IN p_numeroConta INT,
    IN p_clienteId INT,
    IN p_valorPagamento DECIMAL(14,2)
)
BEGIN
    DECLARE v_emprestimoRetirado DECIMAL(14,2);
    DECLARE v_saldoConta DECIMAL(14,2);
    DECLARE v_novoEmprestimoRetirado DECIMAL(14,2);

    -- Verifica se o valor de pagamento é positivo
    IF p_valorPagamento > 0 THEN
        -- Obtém o valor do empréstimo retirado e o saldo da conta
        SELECT emprestimoRetirado, saldoConta 
        INTO v_emprestimoRetirado, v_saldoConta
        FROM conta
        WHERE numeroConta = p_numeroConta
          AND cliente_idCliente = p_clienteId;

        -- Verifica se o valor de pagamento não é maior que o valor do empréstimo retirado
        IF p_valorPagamento > v_emprestimoRetirado THEN
            -- Se o pagamento for maior que o valor do empréstimo retirado, exibe erro
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'O valor do pagamento não pode ser maior que o empréstimo retirado.';
        ELSE
            -- Deduz o valor do pagamento do saldo da conta
            SET v_saldoConta = v_saldoConta - p_valorPagamento;

            -- Atualiza o valor do empréstimo retirado após o pagamento
            SET v_novoEmprestimoRetirado = v_emprestimoRetirado - p_valorPagamento;

            -- Atualiza o saldo da conta
            UPDATE conta
            SET saldoConta = v_saldoConta
            WHERE numeroConta = p_numeroConta
              AND cliente_idCliente = p_clienteId;

            -- Atualiza o valor do empréstimo retirado na tabela conta
            UPDATE conta
            SET emprestimoRetirado = v_novoEmprestimoRetirado
            WHERE numeroConta = p_numeroConta
              AND cliente_idCliente = p_clienteId;

            -- Registra o pagamento no extrato
            INSERT INTO extrato (valorExtrato, descricaoExtrato, conta_numeroConta, conta_cliente_idCliente)
            VALUES (-p_valorPagamento, 'Pagamento de empréstimo', p_numeroConta, p_clienteId);

            -- Confirma a operação
            COMMIT;
        END IF;
    ELSE
        -- Exibe erro se o valor de pagamento for zero ou negativo
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'O valor do pagamento deve ser positivo';
    END IF;
END //

DELIMITER ;
