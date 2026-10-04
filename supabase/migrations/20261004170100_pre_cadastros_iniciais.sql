-- Pré-cadastros iniciais (outubro de 2026). Cada pessoa só consegue criar a conta
-- no "Primeiro acesso" porque o e-mail dela está aqui.
with p as (
  insert into public.pre_cadastros (email, nome) values
    ('maroto@aprimoraej.com', 'Fabricio Maroto'),
    ('arthurfabril@aprimoraej.com', 'Arthur Fabril'),
    ('leticiacavassani@aprimoraej.com', 'Leticia Cavassani'),
    ('tiagotavares@aprimoraej.com', 'Tiago Zanin'),
    ('fredericomartins@aprimoraej.com', 'Frederico Martins'),
    ('theoscamati@aprimoraej.com', 'Theo Scamati'),
    ('consani@aprimoraej.com', 'Eduardo Consani'),
    ('lucas.akio@aprimoraej.com', 'Lucas Akio'),
    ('eduardoaguilera@aprimoraej.com', 'Eduardo Aguilera'),
    ('mateuspegoraro@aprimoraej.com', 'Mateus Pegoraro')
  returning id, email
)
insert into public.pre_cadastro_diretorias (pre_cadastro_id, diretoria, cargo)
select p.id, v.diretoria, v.cargo::public.cargo
from p
join (values
  ('maroto@aprimoraej.com', 'comercial', 'diretor'),
  ('arthurfabril@aprimoraej.com', 'comercial', 'assessor'),
  ('leticiacavassani@aprimoraej.com', 'comercial', 'assessor'),
  ('tiagotavares@aprimoraej.com', 'comercial', 'assessor'),
  ('fredericomartins@aprimoraej.com', 'comercial', 'assessor'),
  ('theoscamati@aprimoraej.com', 'comercial', 'assessor'),
  ('consani@aprimoraej.com', 'comercial', 'assessor'),
  ('lucas.akio@aprimoraej.com', 'presidencia', 'diretor'),
  ('lucas.akio@aprimoraej.com', 'rh', 'diretor'),
  ('eduardoaguilera@aprimoraej.com', 'marketing', 'diretor'),
  ('mateuspegoraro@aprimoraej.com', 'projetos', 'diretor')
) as v(email, diretoria, cargo) on v.email = p.email;
