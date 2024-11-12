#!/bin/bash

# Define as variáveis de conexão ao Domain Controller
#DC_USERNAME="SEU_USUARIO_ADMIN"
read -s -p "Digite o usuário com permissão de domain admin: " DC_USERNAME
echo
# Solicita a senha do usuário administrativo
read -s -p "Digite a senha do usuário $DC_USERNAME: " DC_PASSWORD
echo

# Solicita a CN para pesquisa
#read -s -p "Digite a OU: " CN
echo
#echo "$CN"
echo "Iniciando..."

# Nome do arquivo de saída
OUTPUT_FILE="ultimo_login_usuarios.txt"

# Executa o comando samba-tool user para listar os usuários e redireciona a saída para o arquivo
samba-tool user list -U $DC_USERNAME%$DC_PASSWORD > $OUTPUT_FILE

# Data
DATA=`date +%d-%m-%Y-%H.%M`

# Inicializa contadores
ativadas=0
desativadas=0

# Função para converter o timestamp em data
convert_timestamp() {
    local timestamp=$1
    # Converter para segundos desde a época Unix (1601-01-01 até 1970-01-01)
    unix_time=$(( (timestamp / 10000000) - 11644473600 ))
    # Converter o timestamp para data
    local formatted_date=$(date -d "@$unix_time" +"%d/%m/%y %H:%M:%S")
    echo "$formatted_date"
}

# Loop para processar cada linha do arquivo de saída
while read -r line; do
    username=$(echo $line | cut -d' ' -f1)
    last_logon=$(samba-tool user show $username -U $DC_USERNAME%$DC_PASSWORD | grep "lastLogonTimestamp:" | awk '{print $2}')
    last_passwd=$(samba-tool user show $username -U $DC_USERNAME%$DC_PASSWORD | grep "pwdLastSet:" | awk '{print $2}')
    #ou=$(samba-tool user show $username -U $DC_USERNAME%$DC_PASSWORD | grep "memberOf:" | awk '{print $2}')
    ou=$(samba-tool user show $username -U $DC_USERNAME%$DC_PASSWORD | grep "dn:" | awk -F, '{for(i=1;i<=NF;i++) if($i~/OU=/) print $i}' | cut -d'=' -f2)
    groups=$(samba-tool user getgroups $username -U $DC_USERNAME%$DC_PASSWORD)
    last_logon_converted=$(convert_timestamp $last_logon)
    last_passwd_converted=$(convert_timestamp $last_passwd)
####
# Obtém o valor do atributo userAccountControl
    user_account_control=$(samba-tool user show $username -U $DC_USERNAME%$DC_PASSWORD | grep "userAccountControl" | awk '{print $2}')
# Verifica se a conta está desativada (bit 2 está definido)
    if ((user_account_control & 2)); then
        ((desativadas++))
        account_status="Desativada"
    else
        ((ativadas++))
        account_status="Ativada"
    fi
###
    echo "Usuário: $username Status: $account_status "-" Último Login: $last_logon_converted "-" Última troca de senha em: $last_passwd_converted "-" Setor: $ou Grupos: $groups"
    #echo "Usuário: $username - Último Login: $last_logon_converted" " | " "Última troca de senha em: " $last_passwd_converted  " | " "Setor: " $ou
    #echo "Usuário: $username - Último Login: $last_logon_converted" " | " "Última troca de senha em: " $last_passwd_converted " | " "Setor: " $ou >> /tmp/envio.txt
    #echo "Usuário: $username Status: $account_status" " Último Login: $last_logon_converted" "Última troca de senha em: " $last_passwd_converted "Setor: " $ou >> /tmp/envio.txt
    echo "Usuário: $username Status: $account_status "-" Último Login: $last_logon_converted "-" Última troca de senha em: $last_passwd_converted "-" Setor: $ou Grupos: $groups" >> /tmp/envio.txt
#    sort $OUTPUT_FILE
# Exibe o número total de contas ativadas e desativadas
#echo "Total de Contas Ativadas: $ativadas"
#echo "Total de Contas Desativadas: $desativadas"
done < $OUTPUT_FILE


# Organiza em ordem alfabética a Lista
sort /tmp/envio.txt > /tmp/envio2.txt
echo "Lista de Usuários do AD - "$DATA > /tmp/envio.txt
echo " " >> /tmp/envio.txt


# Realiza a consulta LDAP para contar os usuários na OU
#count=$(ldapsearch -x -D "$DC_USERNAME" -w "$DC_PASSWORD" -b "$base_dn" "(objectClass=user)" | grep -c "dn: ")
# Exibe o resultado
#echo "Número de usuários na Unidade Organizacional $base_dn: $count" >> /tmp/envio.txt
echo " "  >> /tmp/envio.txt
echo " "  >> /tmp/envio.txt
echo " "  >> /tmp/envio.txt
# Exibe o número total de contas ativadas e desativadas
echo "Total de Contas Ativadas: $ativadas" >> /tmp/envio.txt
echo "Total de Contas Desativadas: $desativadas" >> /tmp/envio.txt
cat /tmp/envio2.txt >> /tmp/envio.txt

#Envia E-mail
sudo sendmail -t email@dominio.com.br < /tmp/envio.txt

# Limpa o Usuário e senha da variável após o uso
unset DC_USERNAME
unset DC_PASSWORD
unset CN

# Apaga o arquivo txt
rm -rf /tmp/envio.txt
rm -rf /tmp/envio2.txt
rm -rf ultimo_login_usuarios.txt
