from flask import Flask, render_template, request, redirect, url_for, flash, session
import pymysql
import pymysql.cursors


app = Flask(__name__)
app.secret_key = 'superSecreta'  # Mantenha esta chave segura e única

def get_db_connection():
    #funcao para conectar ao banco de dados
    return pymysql.connect  (
        host='127.0.0.1',
        user='root',
        password='',
        database='banco',
        cursorclass=pymysql.cursors.DictCursor
    )

@app.route('/', methods=['GET', 'POST'  ])
def home():
    if request.method == 'POST':
        cpf = request.form['cpf']
        senha = request.form['senha']
        connection = get_db_connection()
        cursor = connection.cursor()
        # Realiza login no sistema
        cursor.callproc('login',[cpf,senha])
        usuario = cursor.fetchone() 
        cursor.close()
        connection.close()
        
        if usuario:
            # Armazenar o ID do cliente na sessão
            session['cliente_id'] = usuario['idCliente']
            flash('Login bem-sucedido!', 'success')
            return redirect(url_for('menu'))
        else:
            flash('Credenciais inválidas. Tente novamente.', 'error')
            return redirect(url_for('home'))

    return render_template('login.html')    

@app.route('/menu')
def menu():
    # Verificar se o cliente está logado
    if 'cliente_id' not in session:
        session.pop('_flashes', None)
        flash('Você precisa estar logado continuar.', 'error')
        return redirect(url_for('home'))

    cliente_id = session['cliente_id']

    connection = get_db_connection()
    cursor = connection.cursor()

    # Chama o procedimento armazenado `pegaNome`
    cursor.callproc('pegaNome', [cliente_id])
    
    # Itera sobre os resultados do procedimento armazenado
    clienteNome = cursor.fetchone()  # Pega o primeiro resultado

    # Fechar a conexão com o banco de dados
    cursor.close()
    connection.close()

    # Verifique se `clienteNome` tem o valor esperado
    if clienteNome is None:
        flash('Erro ao buscar o nome do cliente.', 'error')
        return redirect(url_for('home'))

    # Renderizar Menu do cliente e passar `clienteNome`
    return render_template('menu.html', clienteNome=clienteNome)

@app.route('/logout')
def logout(): 
    session.pop('_flashes', None)
    session.pop('cliente_id', None)
    flash('Você saiu da sua conta.', 'info')
    return redirect(url_for('home'))

@app.route('/deposito', methods=['GET', 'POST'])
def deposito(): 
    # Verificar se o cliente está logado
    if 'cliente_id' not in session:
        session.pop('_flashes', None)
        flash('Você precisa estar logado para continuar.', 'error')
        return redirect(url_for('home'))

    cliente_id = session['cliente_id']
    
    #Realização do Deposito
    if request.method == 'POST':
        nmrConta = request.form['numeroConta']
        valor = request.form['valor']
        connection = get_db_connection()
        cursor = connection.cursor()

        # Condição para verificar se a operação vai ser realizada ou dará erro
        try:
            cursor.callproc('deposito', [nmrConta, cliente_id, valor, "Depósito"])
            connection.commit()
            session.pop('_flashes', None)
            flash(f'Depósito de + {str(valor)} $ realizado com sucesso!', 'success')
        except pymysql.Error as e:
            #Erro sendo notificado
            session.pop('_flashes', None)
            flash(f'Erro ao realizar operação: {e}', 'error')
        finally:
            # Fechar a conexão com o banco de dados e volta para menu
            cursor.close()
            connection.close()
            return redirect(url_for('menu'))


    # Return da pagina de deposito
    return render_template('deposito.html')
 
    
@app.route('/saque', methods=['GET', 'POST'])
def saque(): 
    # Verificar se o cliente está logado
    if 'cliente_id' not in session:
        session.pop('_flashes', None)
        flash('Você precisa estar logado para continuar.', 'error')
        return redirect(url_for('home'))

    cliente_id = session['cliente_id']
    
    #Realização do Saque
    if request.method == 'POST':
        nmrConta = request.form['numeroConta']
        valor = request.form['valor']
        connection = get_db_connection()
        cursor = connection.cursor()

        # Condição para verificar se a operação vai ser realizada ou dará erro
        try:
            cursor.callproc('saque', [nmrConta, cliente_id, valor, "Saque"])
            connection.commit()
            session.pop('_flashes', None)
            flash(f'Saque de - {str(valor)} $ realizado com sucesso!', 'success')
        except pymysql.Error as e:
            #Erro sendo notificado
            session.pop('_flashes', None)
            flash(f'Erro ao realizar operação: {e}', 'error')
        finally:
            # Fechar a conexão com o banco de dados e volta para menu
            cursor.close()
            connection.close()
            return redirect(url_for('menu'))


    # Return da pagina de saque
    return render_template('saque.html')

@app.route('/transferencia', methods=['GET', 'POST'])
def transferencia(): 
    # Verificar se o cliente está logado
    if 'cliente_id' not in session:
        session.pop('_flashes', None)
        flash('Você precisa estar logado para continuar.', 'error')
        return redirect(url_for('home'))

    cliente_id = session['cliente_id']
    
    #Realização do Transferencia
    if request.method == 'POST':
        nmrContaOrigem = request.form['contaOrigem']
        nmrContaRecebe = request.form['contaDestino']
        valor = request.form['valor']
        connection = get_db_connection()
        cursor = connection.cursor()

        # Condição para verificar se a operação vai ser realizada ou dará erro
        try:
            cursor.callproc('transferencia', [nmrContaOrigem, nmrContaRecebe, cliente_id, valor, "Transferência"])
            connection.commit()
            session.pop('_flashes', None)
            flash(f'Transferencia de {str(valor)} $ para a conta {str(nmrContaRecebe)}!', 'success')
        except pymysql.Error as e:
            #Erro sendo notificado
            session.pop('_flashes', None)
            flash(f'Erro ao realizar operação: {e}', 'error')
        finally:
            # Fechar a conexão com o banco de dados e volta para menu
            cursor.close()
            connection.close()
            return redirect(url_for('menu'))


    # Return da pagina de transf.
    return render_template('transferencia.html')

@app.route('/saldo', methods=['GET', 'POST'])
def saldo(): 
    # Verificar se o cliente está logado
    if 'cliente_id' not in session:
        session.pop('_flashes', None)
        flash('Você precisa estar logado para continuar.', 'error')
        return redirect(url_for('home'))

    cliente_id = session['cliente_id']
    saldoConta = None
    #Realização do Saldo
    if request.method == 'POST':
        nmrConta = request.form['numeroConta']
        connection = get_db_connection()
        cursor = connection.cursor()

        # Condição para verificar se a operação vai ser realizada ou dará erro
        try:
            cursor.callproc('verificar_saldo', [nmrConta, cliente_id])
            saldoConta = cursor.fetchone()
            session.pop('_flashes', None)
            flash(f'Saldo visualizado com sucesso!', 'success')
        except pymysql.Error as e:
            #Erro sendo notificado
            session.pop('_flashes', None)
            flash(f'Erro ao realizar operação: {e}', 'error')
        finally:
            # Fechar a conexão com o banco de dados e volta para menu
            cursor.close()
            connection.close()

    # Return da pagina de saldo
    return render_template('saldo.html', saldoConta=saldoConta)

@app.route('/cartao', methods=['GET', 'POST'])
def cartao(): 
    # Verificar se o cliente está logado
    if 'cliente_id' not in session:
        session.pop('_flashes', None)
        flash('Você precisa estar logado para continuar.', 'error')
        return redirect(url_for('home'))

    cliente_id = session['cliente_id']
    
    #Mostra cartões disponíveis
    connection = get_db_connection()
    cursor = connection.cursor()
    cursor.callproc('consultar_cartoes_cliente',[cliente_id])
    cartoes = cursor.fetchall()
    cursor.close()
    connection.close()
    
    #Realização do Retirada Credito
    if request.method == 'POST':
        nmrConta = request.form['numeroConta']
        nmrCartao = request.form['numeroCartao']
        nmrSeg = request.form['numeroSeg']
        valor = request.form['credito']
        connection = get_db_connection()
        cursor = connection.cursor()

        # Condição para verificar se a operação vai ser realizada ou dará erro
        try:
            cursor.callproc('solicitar_credito', [nmrConta, cliente_id, nmrCartao, nmrSeg, valor])
            connection.commit()
            session.pop('_flashes', None)
            flash(f'Retirada de {str(valor)} $ credito realizado!', 'success')
        except pymysql.Error as e:
            #Erro sendo notificado
            session.pop('_flashes', None)
            flash(f'Erro ao realizar operação: {e}', 'error')
        finally:
            # Fechar a conexão com o banco de dados e volta para menu
            cursor.close()
            connection.close()
            return redirect(url_for('menu'))


    # Return da pagina de saque
    return render_template('cartao_credito.html', cartoes=cartoes)

@app.route('/emprestimo', methods=['GET', 'POST'])
def emprestimo(): 
    # Verificar se o cliente está logado
    if 'cliente_id' not in session:
        session.pop('_flashes', None)
        flash('Você precisa estar logado para continuar.', 'error')
        return redirect(url_for('home'))

    cliente_id = session['cliente_id']
    
    #Realização do empréstimo
    if request.method == 'POST':
        nmrConta = request.form['numeroConta']
        valor = request.form['valorEmprestimo']
        connection = get_db_connection()
        cursor = connection.cursor()

        # Condição para verificar se a operação vai ser realizada ou dará erro
        try:
            cursor.callproc('solicitar_emprestimo', [nmrConta, cliente_id, valor])
            connection.commit()
            session.pop('_flashes', None)
            flash(f'Emprestimo para conta de {str(valor)} $ realizado com sucesso!', 'success')
        except pymysql.Error as e:
            #Erro sendo notificado
            session.pop('_flashes', None)
            flash(f'Erro ao realizar operação: {e}', 'error')
        finally:
            # Fechar a conexão com o banco de dados e volta para menu
            cursor.close()
            connection.close()
            return redirect(url_for('menu'))


    # Return da pagina de saque
    return render_template('emprestimo.html')

@app.route('/extrato')
def extrato(): 
    # Verificar se o cliente está logado
    if 'cliente_id' not in session:
        session.pop('_flashes', None)
        flash('Você precisa estar logado para continuar.', 'error')
        return redirect(url_for('home'))

    cliente_id = session['cliente_id']
    
    #Mostra extrato
    connection = get_db_connection()
    cursor = connection.cursor()
    cursor.callproc('consultar_extrato',[cliente_id])
    extrato = cursor.fetchall()
    cursor.close()
    connection.close()
    
    session.pop('_flashes', None)
    flash(f'Extrato realizado', 'success')

    # Return da pagina de saque
    return render_template('extrato.html', extrato=extrato)

@app.route('/pagarEmpCred')
def pagarEmpCred():
    # Verificar se o cliente está logado
    if 'cliente_id' not in session:
        session.pop('_flashes', None)
        flash('Você precisa estar logado para continuar.', 'error')
        return redirect(url_for('home'))

    cliente_id = session['cliente_id']
    
    return render_template('pagarEmpCred.html')

@app.route('/pagar_emprestimo', methods=['GET', 'POST'])
def pagar_emprestimo(): 
    # Verificar se o cliente está logado
    if 'cliente_id' not in session:
        session.pop('_flashes', None)
        flash('Você precisa estar logado para continuar.', 'error')
        return redirect(url_for('home'))

    cliente_id = session['cliente_id']
    
    #Realização do pagamento empréstimo
    if request.method == 'POST':
        nmrConta = request.form['numeroConta']
        valor = request.form['valorEmprestimo']
        connection = get_db_connection()
        cursor = connection.cursor()

        # Condição para verificar se a operação vai ser realizada ou dará erro
        try:
            cursor.callproc('pagar_emprestimo', [nmrConta,cliente_id,valor])
            connection.commit()
            session.pop('_flashes', None)
            flash(f'Pagamento de {str(valor)} $ realizado para Empréstimoo, sucesso!', 'success')
        except pymysql.Error as e:
            #Erro sendo notificado
            session.pop('_flashes', None)
            flash(f'Erro ao realizar operação: {e}', 'error')
        finally:
            # Fechar a conexão com o banco de dados e volta para menu
            cursor.close()
            connection.close()
            return redirect(url_for('menu'))


    # Return da pagina de saque
    return render_template('pagar_emprestimo.html')

@app.route('/pagar_credito', methods=['GET', 'POST'])
def pagar_credito(): 
    # Verificar se o cliente está logado
    if 'cliente_id' not in session:
        session.pop('_flashes', None)
        flash('Você precisa estar logado para continuar.', 'error')
        return redirect(url_for('home'))

    cliente_id = session['cliente_id']
    
    #Realização do Pagamento Credito
    if request.method == 'POST':
        nmrConta = request.form['numeroConta']
        nmrCartao = request.form['numeroCartao']
        nmrSeg = request.form['numeroSeg']
        valor = request.form['credito']
        connection = get_db_connection()
        cursor = connection.cursor()

        # Condição para verificar se a operação vai ser realizada ou dará erro
        try:
            cursor.callproc('pagar_credito', [nmrConta, cliente_id, nmrCartao, nmrSeg, valor])
            connection.commit()
            session.pop('_flashes', None)
            flash(f'Pagamento de {str(valor)} $ realizado para Crédito, sucesso!', 'success')
        except pymysql.Error as e:
            #Erro sendo notificado
            session.pop('_flashes', None)
            flash(f'Erro ao realizar operação: {e}', 'error')
        finally:
            # Fechar a conexão com o banco de dados e volta para menu
            cursor.close()
            connection.close()
            return redirect(url_for('menu'))
    
    return render_template('pagar_credito.html')

if __name__ == '__main__':
    app.run(debug=True)
