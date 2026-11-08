
vizinha(X,Y,VX,Y) :- VX is X + 1, map_size(MX,_), VX =< MX.
vizinha(X,Y,VX,Y) :- VX is X - 1, VX >= 1.
vizinha(X,Y,X,VY) :- VY is Y + 1, map_size(_,MY), VY =< MY.
vizinha(X,Y,X,VY) :- VY is Y - 1, VY >= 1.

direita(norte,leste).
direita(leste,sul).
direita(sul,oeste).
direita(oeste,norte).

dano_maximo(80).
altura_contorno(2).
vida_baixa :- energia(E), dano_maximo(D), E =< D.

pisada(X,Y) :- visitado(X,Y).
pisada(X,Y) :- posicao(X,Y,_).

tem_perigo(L) :- member(P,L), member(P,[brisa,passos,palmas]),!.

%casa que o agente sabe que e segura
livre(1,1).
livre(X,Y) :- certeza(X,Y), memory(X,Y,L), \+tem_perigo(L).

%a origem so entra como destino, senao o jogo acaba no meio do caminho.
%na volta pra casa da pra cruzar inimigo que ja conhecemos
passavel(_,1,1) :- !, fail.
passavel(_,X,Y) :- livre(X,Y).
passavel(volta,X,Y) :- visitado(X,Y), certeza(X,Y), memory(X,Y,[passos]).

%busca em largura. o caminho so passa por casas passaveis, so o destino pode ser outra
bfs(Modo,Alvos,Caminho) :-
	posicao(X,Y,_),
	bfs(Modo,Alvos,[[(X,Y)]],[(X,Y)],Rev),
	reverse(Rev,Caminho).

bfs(_,Alvos,[[(X,Y)|R]|_],_,[(X,Y)|R]) :- member((X,Y),Alvos),!.
bfs(Modo,Alvos,[[(X,Y)|R]|Fila],Vis,Caminho) :-
	findall((VX,VY), (vizinha(X,Y,VX,VY), \+member((VX,VY),Vis), (passavel(Modo,VX,VY); member((VX,VY),Alvos))), Todos),
	sort(Todos,Novos),
	findall([N,(X,Y)|R], member(N,Novos), Caminhos),
	append(Fila,Caminhos,Fila2),
	append(Vis,Novos,Vis2),
	bfs(Modo,Alvos,Fila2,Vis2,Caminho).

direcao(X,Y,VX,VY,D) :- DX is VX - X, DY is VY - Y, sentido(DX,DY,D).
sentido(0,1,norte).
sentido(0,-1,sul).
sentido(1,0,leste).
sentido(-1,0,oeste).

gira(D,D,andar) :- !.
gira(D,Alvo,virar_direita) :- direita(D,Alvo),!.
gira(D,Alvo,virar_esquerda) :- direita(Alvo,D),!.
gira(_,_,virar_direita).

%primeira acao do caminho ate o alvo mais perto
vai_para(Modo,Alvos,Acao) :-
	posicao(X,Y,D),
	bfs(Modo,Alvos,[_,(VX,VY)|_]),
	direcao(X,Y,VX,VY,Alvo),
	gira(D,Alvo,Acao).

%varredura: linha 1 pra direita, linha 2 pra esquerda, linha 3 pra direita...
ordem(X,Y,K) :- map_size(MX,_), (Y mod 2 =:= 1 -> XK = X ; XK is MX + 1 - X), K is Y * 100 + XK.

proxima(AX,AY) :-
	findall(K-(X,Y), (livre(X,Y), \+pisada(X,Y), ordem(X,Y,K)), Lista),
	sort(Lista,Ordenada),
	member(_-(AX,AY),Ordenada),
	bfs(seguro,[(AX,AY)],_),!.

%casa que o agente ainda nao sabe nada, nem como suspeita
desconhecida(X,Y) :- map_size(MX,MY), between(1,MY,Y), between(1,MX,X), \+memory(X,Y,_), \+pisada(X,Y).

%primeira casa desconhecida na ordem da varredura. fica na linha mais baixa que ainda nao acabou
parada(PX,PY) :-
	findall(K-(X,Y), (desconhecida(X,Y), ordem(X,Y,K)), Lista),
	sort(Lista,[_-(PX,PY)|_]).

%se a varredura ia subir de linha mas a atual ainda tem casa desconhecida, tenta contornar:
%vai pra casa segura mais perto dela, sem se afastar mais que altura_contorno linhas
contorno(Linha,AX,AY) :-
	parada(PX,PY), PY < Linha,
	altura_contorno(H), Teto is PY + H,
	findall(D-(X,Y), (livre(X,Y), \+pisada(X,Y), Y =< Teto, D is abs(X - PX) + abs(Y - PY)), Lista),
	sort(Lista,Ordenada),
	member(_-(AX,AY),Ordenada),
	bfs(seguro,[(AX,AY)],_),!.

%o dano do inimigo vale pra cada acao na casa dele, ate virar. sai girando o minimo
fugir(Acao) :-
	posicao(X,Y,D), memory(X,Y,L), member(passos,L),
	direita(D,Dir), direita(Esq,D), direita(Dir,Tras),
	member(Alvo,[D,Dir,Esq,Tras]),
	sentido(DX,DY,Alvo), VX is X + DX, VY is Y + DY, livre(VX,VY),
	gira(D,Alvo,Acao),!.

cura_conhecida(X,Y) :- livre(X,Y), memory(X,Y,L), member(reflexo,L), \+posicao(X,Y,_).

%chance de inimigo em (X,Y): 1 dividido pelas suspeitas em volta de cada vizinha
%que ouviu passos. com mais de uma vizinha vale a pior
chance(X,Y,C) :-
	findall(P, (vizinha(X,Y,VX,VY), pisada(VX,VY),
	            findall(1, (vizinha(VX,VY,SX,SY), \+pisada(SX,SY), memory(SX,SY,L), member(passos,L)), Suspeitas),
	            length(Suspeitas,N), N > 0, P is 1 / N), Ps),
	max_list(Ps,C).

%curar so vale se ainda tem o que explorar ou se a volta pra casa nao e segura
vale_curar :- (proxima(_,_) ; menor_risco(_,_)),!.
vale_curar :- \+bfs(seguro,[(1,1)],_).

candidata_risco(X,Y,C) :- memory(X,Y,[passos]), \+pisada(X,Y), (certeza(X,Y) -> C = 1 ; chance(X,Y,C)).

menor_risco(AX,AY) :-
	findall(C-(X,Y), candidata_risco(X,Y,C), Lista),
	sort(Lista,Ordenada),
	member(_-(AX,AY),Ordenada),
	bfs(seguro,[(AX,AY)],_),!.

executa_acao(_) :- fim_de_jogo(_),!,fail.
executa_acao(pegar) :- posicao(X,Y,_), memory(X,Y,L), member(brilho,L),!.
executa_acao(pegar) :- vida_baixa, vale_curar, posicao(X,Y,_), memory(X,Y,L), member(reflexo,L),!.
executa_acao(A) :- fugir(A),!.
executa_acao(A) :- vida_baixa, vale_curar, findall((X,Y), cura_conhecida(X,Y), Curas), Curas \== [], vai_para(seguro,Curas,A),!.
executa_acao(A) :- proxima(_,Linha), contorno(Linha,X,Y), vai_para(seguro,[(X,Y)],A),!.
executa_acao(A) :- proxima(X,Y), vai_para(seguro,[(X,Y)],A),!.
executa_acao(A) :- \+vida_baixa, menor_risco(X,Y), vai_para(seguro,[(X,Y)],A),!.
executa_acao(A) :- vai_para(seguro,[(1,1)],A),!.
executa_acao(A) :- vai_para(volta,[(1,1)],A),!.
