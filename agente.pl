
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Geometria
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

dentro(X,Y) :- map_size(MX,MY), X >= 1, X =< MX, Y >= 1, Y =< MY.

%vizinhas de (X,Y), sem diagonal
vizinha(X,Y,VX,Y) :- VX is X + 1, dentro(VX,Y).
vizinha(X,Y,VX,Y) :- VX is X - 1, dentro(VX,Y).
vizinha(X,Y,X,VY) :- VY is Y + 1, dentro(X,VY).
vizinha(X,Y,X,VY) :- VY is Y - 1, dentro(X,VY).

direita(norte,leste).
direita(leste,sul).
direita(sul,oeste).
direita(oeste,norte).
esquerda(A,B) :- direita(B,A).

%direcao de (X,Y) ate a vizinha (VX,VY)
direcao(X,Y,X,VY,norte) :- VY =:= Y + 1.
direcao(X,Y,X,VY,sul) :- VY =:= Y - 1.
direcao(X,Y,VX,Y,leste) :- VX =:= X + 1.
direcao(X,Y,VX,Y,oeste) :- VX =:= X - 1.

%giros necessarios para ficar de frente para a direcao D2
giros(D,D,0) :- !.
giros(D,D2,1) :- (direita(D,D2); esquerda(D,D2)),!.
giros(_,_,2).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Conhecimento
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%casa onde o agente ja esteve ou esta agora
pisada(X,Y) :- visitado(X,Y).
pisada(X,Y) :- posicao(X,Y,_).

perigo(L) :- member(P,L), memberchk(P,[brisa,passos,palmas]),!.

%casa segura. a origem entra de graca porque o agente comeca nela
livre(1,1).
livre(X,Y) :- certeza(X,Y), memory(X,Y,L), \+perigo(L).

%a origem so entra como destino, se entrar no meio do caminho o jogo acaba.
%na volta pra casa da pra cruzar inimigo ja conhecido, se a energia aguentar
passavel(_,1,1) :- !, fail.
passavel(_,X,Y) :- livre(X,Y).
passavel(alvo_casa,X,Y) :- certeza(X,Y), memory(X,Y,[passos]), energia(E), E > 80.
passavel(alvo_casa_forcado,X,Y) :- certeza(X,Y), memory(X,Y,[passos]).

poco_certo(X,Y) :- certeza(X,Y), memory(X,Y,L), member(brisa,L).

%brisa em (X,Y) ja tem explicacao se tem poco certo do lado
explicada(X,Y) :- vizinha(X,Y,PX,PY), poco_certo(PX,PY),!.

%quantas vizinhas de (X,Y) ainda podem ser o poco
suspeitas(X,Y,N) :- findall(1, (vizinha(X,Y,VX,VY), \+pisada(VX,VY), memory(VX,VY,L), member(brisa,L)), Lista), length(Lista,N).

%chance de poco em (X,Y). cada casa pisada vizinha sente brisa; se a brisa
%ja tem explicacao a chance cai pro basico (8 pocos em 144 casas)
risco_poco(X,Y,R) :-
	findall(P, (vizinha(X,Y,BX,BY), pisada(BX,BY), \+explicada(BX,BY), suspeitas(BX,BY,K), P is 1 / K), Ps),
	(   Ps = [] -> R = 0.06
	;   prod_complemento(Ps,Prod), R is 1 - Prod
	).

prod_complemento([],1).
prod_complemento([P|T],R) :- prod_complemento(T,RT), R is (1 - P) * RT.

risco_aceito(R) :- R =< 0.1.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Objetivos
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

alvo_explorar(X,Y) :- livre(X,Y), \+visitado(X,Y), \+posicao(X,Y,_).

%casa incerta que ainda pode ter perigo
suspeita(X,Y) :- memory(X,Y,L), perigo(L), \+certeza(X,Y), \+pisada(X,Y).

%casa segura colada numa suspeita. pisar nela ajuda a descobrir o que tem la
alvo_contornar(X,Y) :- alvo_explorar(X,Y), vizinha(X,Y,SX,SY), suspeita(SX,SY).

alvo_energia(X,Y) :- livre(X,Y), memory(X,Y,L), member(reflexo,L), \+posicao(X,Y,_).

%casa incerta onde so pode ter inimigo
alvo_inimigo(X,Y) :- memory(X,Y,L), L = [passos], \+certeza(X,Y), \+visitado(X,Y), \+posicao(X,Y,_).

alvo_celula(AX,AY,X,Y) :- X =:= AX, Y =:= AY.

alvo_casa(X,Y) :- X =:= 1, Y =:= 1, \+posicao(1,1,_).
alvo_casa_forcado(X,Y) :- alvo_casa(X,Y).

%varredura por linhas, de baixo pra cima. linha impar vai pra direita, par pra esquerda
ordem_varredura(X,Y,K) :- map_size(MX,_), (Y mod 2 =:= 1 -> XK = X ; XK is MX + 1 - X), K is Y * 100 + XK.

%primeira casa segura da varredura que da pra alcançar
proximo_varredura(AX,AY) :-
	findall(K-(X,Y), (alvo_explorar(X,Y), ordem_varredura(X,Y,K)), Lista),
	sort(Lista,Ordenada),
	member(_-(AX,AY),Ordenada),
	bfs(alvo_celula(AX,AY),_),!.

%casa com risco de poco aceitavel, a de menor risco primeiro
aposta(AX,AY) :-
	energia(E),
	findall(R-(X,Y), candidata_poco(X,Y,E,R), Lista),
	sort(Lista,Ordenada),
	member(R-(AX,AY),Ordenada),
	risco_aceito(R),
	bfs(alvo_celula(AX,AY),_),!.

candidata_poco(X,Y,E,R) :-
	memory(X,Y,L), member(brisa,L), \+member(palmas,L),
	\+certeza(X,Y), \+pisada(X,Y),
	(member(passos,L) -> E > 80 ; true),
	risco_poco(X,Y,R).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Planejamento
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%busca em largura so por casas livres. o destino pode ser casa nao livre
bfs(Alvo,Caminho) :- posicao(X,Y,_), bfs([[(X,Y)]],[(X,Y)],Alvo,Rev), reverse(Rev,Caminho).

bfs([[(X,Y)|R]|_], _, Alvo, [(X,Y)|R]) :- call(Alvo,X,Y),!.
bfs([[(X,Y)|R]|Fila], Vis, Alvo, Caminho) :-
	findall((VX,VY), (vizinha(X,Y,VX,VY), \+member((VX,VY),Vis), once((passavel(Alvo,VX,VY); call(Alvo,VX,VY)))), Novos),
	findall([N,(X,Y)|R], member(N,Novos), Ext),
	append(Fila,Ext,Fila2),
	append(Vis,Novos,Vis2),
	bfs(Fila2,Vis2,Alvo,Caminho).

passo(X,Y,D,VX,VY,andar) :- direcao(X,Y,VX,VY,D),!.
passo(X,Y,D,VX,VY,virar_direita) :- direcao(X,Y,VX,VY,D2), direita(D,D2),!.
passo(X,Y,D,VX,VY,virar_esquerda) :- direcao(X,Y,VX,VY,D2), esquerda(D,D2),!.
passo(_,_,_,_,_,virar_direita).

%primeira acao do caminho ate o alvo mais proximo
vai_para(Alvo,Acao) :- posicao(X,Y,D), bfs(Alvo,[_,(VX,VY)|_]), passo(X,Y,D,VX,VY,Acao).

%o dano do inimigo vale pra cada acao na casa dele, inclusive virar.
%sai pelo lado que pede menos giro
fugir(Acao) :-
	posicao(X,Y,D), memory(X,Y,L), member(passos,L),
	findall(C-A, (vizinha(X,Y,VX,VY), livre(VX,VY), direcao(X,Y,VX,VY,D2), giros(D,D2,C), passo(X,Y,D,VX,VY,A)), Opcoes),
	Opcoes \== [],
	keysort(Opcoes,[_-Acao|_]).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Decisao
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%a ordem das regras e a prioridade. se nenhuma serve o agente para
executa_acao(_) :- fim_de_jogo(_),!,fail.
executa_acao(pegar) :- posicao(X,Y,_), memory(X,Y,L), member(brilho,L),!.
executa_acao(pegar) :- energia(E), E =< 50, posicao(X,Y,_), memory(X,Y,L), member(reflexo,L),!.
executa_acao(A) :- fugir(A),!.
executa_acao(A) :- energia(E), E =< 50, vai_para(alvo_energia,A),!.
executa_acao(A) :- vai_para(alvo_contornar,A),!.
executa_acao(A) :- proximo_varredura(AX,AY), vai_para(alvo_celula(AX,AY),A),!.
executa_acao(A) :- aposta(AX,AY), vai_para(alvo_celula(AX,AY),A),!.
executa_acao(A) :- energia(E), E > 80, vai_para(alvo_inimigo,A),!.
executa_acao(A) :- vai_para(alvo_casa,A),!.
executa_acao(A) :- vai_para(alvo_casa_forcado,A),!.
