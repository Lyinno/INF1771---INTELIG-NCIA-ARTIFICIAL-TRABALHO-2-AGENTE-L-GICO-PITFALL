
vizinha(X,Y,VX,Y) :- VX is X + 1, map_size(MX,_), VX =< MX.
vizinha(X,Y,VX,Y) :- VX is X - 1, VX >= 1.
vizinha(X,Y,X,VY) :- VY is Y + 1, map_size(_,MY), VY =< MY.
vizinha(X,Y,X,VY) :- VY is Y - 1, VY >= 1.

direita(norte,leste).
direita(leste,sul).
direita(sul,oeste).
direita(oeste,norte).

dano_maximo(80).
custo_morte(1000).
custo_visitada(10).

pisada(X,Y) :- visitado(X,Y),!.
pisada(X,Y) :- posicao(X,Y,_).

tem_perigo(L) :- member(P,L), member(P,[brisa,passos,palmas]),!.

livre(1,1).
livre(X,Y) :- certeza(X,Y), memory(X,Y,L), \+tem_perigo(L).

cura_conhecida(X,Y) :- memory(X,Y,L), member(reflexo,L).

direcao(X,Y,VX,VY,D) :- DX is VX - X, DY is VY - Y, sentido(DX,DY,D).
sentido(0,1,norte).
sentido(0,-1,sul).
sentido(1,0,leste).
sentido(-1,0,oeste).

gira(D,D,andar) :- !.
gira(D,Alvo,virar_direita) :- direita(D,Alvo),!.
gira(D,Alvo,virar_esquerda) :- direita(Alvo,D),!.
gira(_,_,virar_direita).

passo([(X,Y),(VX,VY)|_],Acao) :- posicao(X,Y,D), direcao(X,Y,VX,VY,Alvo), gira(D,Alvo,Acao).

%o dano do inimigo vale pra cada acao na casa dele, ate virar. sai girando o minimo
fugir(Acao) :-
	posicao(X,Y,D), memory(X,Y,L), member(passos,L),
	direita(D,Dir), direita(Esq,D), direita(Dir,Tras),
	member(Alvo,[D,Dir,Esq,Tras]),
	sentido(DX,DY,Alvo), VX is X + DX, VY is Y + DY, livre(VX,VY),
	gira(D,Alvo,Acao),!.

%chance de ter o que a percepcao Tag avisa em (X,Y). cada vizinha pisada que sentiu soma
%1 dividido pelas suspeitas que ela tem em volta. mais vizinhas, mais chance (no maximo 1)
risco(_,X,Y,1) :- certeza(X,Y),!.
risco(Tag,X,Y,R) :-
	findall(P, (vizinha(X,Y,VX,VY), pisada(VX,VY), suspeitas(Tag,VX,VY,N), N > 0, P is 1 / N), Ps),
	(Ps == [] -> R = 1 ; sum_list(Ps,S), R is min(1,S)).

suspeitas(Tag,X,Y,N) :-
	findall(1, (vizinha(X,Y,VX,VY), \+pisada(VX,VY), memory(VX,VY,L), member(Tag,L)), Lista),
	length(Lista,N).

%quanto custa cada perigo. na volta, com vida pra aguentar um golpe, o inimigo nao custa nada
prejuizo(passos,volta(E),0) :- dano_maximo(D), E > D,!.
prejuizo(passos,_,D) :- dano_maximo(D).
prejuizo(brisa,_,M) :- custo_morte(M).
prejuizo(palmas,_,M) :- custo_morte(M).

dano(Modo,X,Y,D) :-
	(memory(X,Y,L) -> true ; L = []),
	findall(P, (member(Tag,L), prejuizo(Tag,Modo,B), B > 0, risco(Tag,X,Y,R), P is B * R), Ps),
	sum_list(Ps,D).

%1 do passo, mais 10 se ja foi pisada, mais o dano esperado
custo(Modo,X,Y,C) :-
	custo_visitada(V),
	(pisada(X,Y) -> Extra = V ; Extra = 0),
	dano(Modo,X,Y,D),
	C is 1 + Extra + D.

%a origem so entra como destino, senao o jogo acaba no meio do caminho
pode(Modo,Alvo,X,Y) :- (X =:= 1, Y =:= 1 -> Alvo = (1,1) ; true), pode(Modo,X,Y).
pode(estrito,X,Y) :- \+ (memory(X,Y,L), tem_perigo(L)).
pode(ida,X,Y) :- \+intransponivel(X,Y).
pode(volta(_),X,Y) :- \+intransponivel(X,Y).

intransponivel(X,Y) :- certeza(X,Y), memory(X,Y,L), (member(brisa,L) ; member(palmas,L)).

h((X,Y),(AX,AY),H) :- H is abs(X - AX) + abs(Y - AY).

a_estrela(Modo,Ini,Alvo,Custo,Caminho) :-
	h(Ini,Alvo,H),
	busca(Modo,Alvo,[no(H,0,Ini,[Ini])],[],Custo,Rev),
	reverse(Rev,Caminho).

busca(_,Alvo,[no(_,G,Alvo,Cam)|_],_,G,Cam) :- !.
busca(Modo,Alvo,[no(_,_,Pos,_)|Resto],Fechados,Custo,Cam) :-
	memberchk(Pos,Fechados),!,
	busca(Modo,Alvo,Resto,Fechados,Custo,Cam).
busca(Modo,Alvo,[no(_,G,(X,Y),Cam)|Resto],Fechados,Custo,Caminho) :-
	findall(no(F,G2,(VX,VY),[(VX,VY)|Cam]),
		(vizinha(X,Y,VX,VY), \+memberchk((VX,VY),Fechados), pode(Modo,Alvo,VX,VY),
		 custo(Modo,VX,VY,C), G2 is G + C, h((VX,VY),Alvo,H), F is G2 + H),
		Novos),
	append(Resto,Novos,Aberta0),
	sort(1,@=<,Aberta0,Aberta),
	busca(Modo,Alvo,Aberta,[(X,Y)|Fechados],Custo,Caminho).

%varredura em zigzag: linha 1 pra direita, linha 2 pra esquerda, linha 3 pra direita...
ordem(X,Y,K) :- map_size(MX,_), (Y mod 2 =:= 1 -> XK = X ; XK is MX + 1 - X), K is Y * 100 + XK.

%casa fechada: ja pisada, ou perigo que o agente tem certeza que existe
fechada(X,Y) :- pisada(X,Y).
fechada(X,Y) :- certeza(X,Y), memory(X,Y,L), tem_perigo(L).

alvos(Lista) :-
	map_size(MX,MY),
	findall(K-(X,Y), (between(1,MY,Y), between(1,MX,X), \+fechada(X,Y), ordem(X,Y,K)), L0),
	sort(L0,L1),
	findall(C, member(_-C,L1), Lista).

%casas que da pra chegar sem passar por nada suspeito
alcancadas(Alc) :- posicao(X,Y,_), varre([(X,Y)],[(X,Y)],Alc).

varre([],Vis,Vis).
varre([(X,Y)|Fila],Vis,Alc) :-
	findall((VX,VY), (vizinha(X,Y,VX,VY), \+memberchk((VX,VY),Vis), pode(estrito,nenhum,VX,VY)), Todos),
	sort(Todos,Novos),
	append(Fila,Novos,Fila2),
	append(Vis,Novos,Vis2),
	varre(Fila2,Vis2,Alc).

%quantas casas letais (poco, teletransporte) e de inimigo tem no caminho
perigos([_|Cauda],Letais,Inimigos) :-
	findall(1, (member((X,Y),Cauda), memory(X,Y,L), (member(brisa,L) ; member(palmas,L))), Ls),
	length(Ls,Letais),
	findall(1, (member((X,Y),Cauda), memory(X,Y,L), member(passos,L)), Is),
	length(Is,Inimigos).

%a estrela ate o item de cura mais barato
plano_cura(Acao) :-
	posicao(X,Y,_),
	findall(C-Cam, (cura_conhecida(CX,CY), a_estrela(ida,(X,Y),(CX,CY),C,Cam)), L0),
	keysort(L0,[_-Cam|_]),
	(Cam = [_] -> Acao = pegar ; passo(Cam,Acao)).

%so tem que cruzar perigo. cura antes se a vida nao aguenta, aceita qualquer risco se
%ainda nao tem ouro, senao so cruza o que a vida aguenta e nao mata de vez
decide(Cam,Acao) :-
	perigos(Cam,Letais,Inimigos), energia(E), dano_maximo(M),
	(   Inimigos > 0, E =< M * Inimigos, plano_cura(Acao) -> true
	;   ouros(0) -> passo(Cam,Acao)
	;   Letais =:= 0, E > M * Inimigos, passo(Cam,Acao)
	).

ida(Acao) :-
	alvos(Alvos), posicao(X,Y,_),
	alcancadas(Alc),
	member(Alvo,Alvos), memberchk(Alvo,Alc),
	a_estrela(estrito,(X,Y),Alvo,_,Cam),!,
	passo(Cam,Acao).
ida(Acao) :-
	alvos(Alvos), posicao(X,Y,_),
	findall(C-Cam, (member(Alvo,Alvos), a_estrela(ida,(X,Y),Alvo,C,Cam)), L0),
	keysort(L0,L),
	member(_-Cam,L),
	decide(Cam,Acao),!.

%volta pra origem. compara ir direto com passar antes por um item de cura
volta(Acao) :-
	posicao(X,Y,_), energia(E), E2 is min(100,E + 50),
	a_estrela(volta(E),(X,Y),(1,1),CD,CamD),
	findall(C-Cam, (cura_conhecida(CX,CY), a_estrela(volta(E),(X,Y),(CX,CY),C1,Cam),
	                a_estrela(volta(E2),(CX,CY),(1,1),C2,_), C is C1 + 5 + C2), L0),
	keysort(L0,L),
	(   L = [C-Cam|_], C < CD -> (Cam = [_] -> Acao = pegar ; passo(Cam,Acao))
	;   passo(CamD,Acao)
	).

executa_acao(_) :- fim_de_jogo(_),!,fail.
executa_acao(pegar) :- posicao(X,Y,_), memory(X,Y,L), member(brilho,L),!.
executa_acao(A) :- fugir(A),!.
executa_acao(A) :- ida(A),!.
executa_acao(A) :- volta(A),!.
