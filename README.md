# INT-HPC - P4 code
O código usado tem como base a atividade "MRI" do tutorial.
Ele deve ser utilizado dentro da VM proposta para realizar o tutorial.
Um vez feito isso, deve-se clonar este repo no diretório desejado.
O código é auto-contido, ou seja, não depende de outros arquivos para compilar.
Para compilar é necessário executar o comando 'make', 'make stop' e 'make clean' para parar e limpar os dados, respectivamente.

# Iperf3
Para usar o iperf3 é necessário instalar o mesmo.

```bash
sudo apt-get install iperf3
```

## Utilização
iperf3 -s # Execução no host servidor 's'
iperf3 -c $IP 'or' $hostname -b 1G -l 8900 -u -P 4 -t 40 # Execução no client 'c'. 'b' bandwidth. 'u' UDP. 'l' lenght. 'P' parallel 't' time.

# NPB
Necessário fazer o download do NPB e instalar alguns pacotes.

```bash
wget https://www.nas.nasa.gov/assets/npb/NPB3.4.tar.gz
sudo apt-get install libopenmpi-dev gfortran
```
Modificar make.def para utilizar mpifort
Modificar suite.def para compilar a aplicação desejada e classe.
Compilar 

```bash
make suite
```
## Utilização

```bash
mpirun -np $process -machinefile $machinefile $app
```
Para executar o NPB-MPI é necessário que os hosts tenham acesso SSH um ao outro.
Primeiro definir os hosts e seus respectivos IPs em /etc/hosts.
Em cada hosts que se deseja executar, por exemplo hosts h1 e h5, deve-se abrir o terminal xterm h1 h5 e dentro de ambos os terminais executar /usr/sbin/sshd -D. 
