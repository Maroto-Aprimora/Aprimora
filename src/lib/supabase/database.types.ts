// Tipos gerados a partir do banco (Supabase → generate_typescript_types).
// NÃO edite à mão: depois de cada migração, gere de novo (veja docs/DESENVOLVIMENTO.md).

export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[];

export type Database = {
  __InternalSupabase: { PostgrestVersion: "14.18" };
  public: {
    Tables: {
      auditoria: {
        Row: { acao: string; autor_id: string | null; created_at: string; dados: Json | null; entidade: string; entidade_id: string | null; id: number };
        Insert: { acao: string; autor_id?: string | null; created_at?: string; dados?: Json | null; entidade: string; entidade_id?: string | null; id?: never };
        Update: { acao?: string; autor_id?: string | null; created_at?: string; dados?: Json | null; entidade?: string; entidade_id?: string | null; id?: never };
        Relationships: [];
      };
      contatos: {
        Row: { cargo: string | null; created_at: string; criado_por: string | null; decisor: boolean; email: string | null; empresa_id: string; id: string; linkedin: string | null; nao_contatar: boolean; nome: string; observacoes: string | null; telefone: string | null; updated_at: string };
        Insert: { cargo?: string | null; created_at?: string; criado_por?: string | null; decisor?: boolean; email?: string | null; empresa_id: string; id?: string; linkedin?: string | null; nao_contatar?: boolean; nome: string; observacoes?: string | null; telefone?: string | null; updated_at?: string };
        Update: { cargo?: string | null; created_at?: string; criado_por?: string | null; decisor?: boolean; email?: string | null; empresa_id?: string; id?: string; linkedin?: string | null; nao_contatar?: boolean; nome?: string; observacoes?: string | null; telefone?: string | null; updated_at?: string };
        Relationships: [
          { foreignKeyName: "contatos_criado_por_fkey"; columns: ["criado_por"]; isOneToOne: false; referencedRelation: "membros"; referencedColumns: ["id"] },
          { foreignKeyName: "contatos_empresa_id_fkey"; columns: ["empresa_id"]; isOneToOne: false; referencedRelation: "empresas"; referencedColumns: ["id"] },
        ];
      };
      diretorias: {
        Row: { ativa: boolean; nome: string; ordem: number; slug: string };
        Insert: { ativa?: boolean; nome: string; ordem?: number; slug: string };
        Update: { ativa?: boolean; nome?: string; ordem?: number; slug?: string };
        Relationships: [];
      };
      empresas: {
        Row: { cidade: string | null; cnpj: string | null; cnpj_digitos: string | null; created_at: string; criado_por: string | null; email_principal: string | null; email_secundario: string | null; email_terciario: string | null; endereco: string | null; ficticio: boolean; id: string; nome: string; nome_normalizado: string | null; observacoes: string | null; razao_social: string | null; rede_social: string | null; segmento_id: string | null; site: string | null; telefone: string | null; telefone_digitos: string | null; uf: string | null; updated_at: string };
        Insert: { cidade?: string | null; cnpj?: string | null; created_at?: string; criado_por?: string | null; email_principal?: string | null; email_secundario?: string | null; email_terciario?: string | null; endereco?: string | null; ficticio?: boolean; id?: string; nome: string; observacoes?: string | null; razao_social?: string | null; rede_social?: string | null; segmento_id?: string | null; site?: string | null; telefone?: string | null; uf?: string | null; updated_at?: string };
        Update: { cidade?: string | null; cnpj?: string | null; created_at?: string; criado_por?: string | null; email_principal?: string | null; email_secundario?: string | null; email_terciario?: string | null; endereco?: string | null; ficticio?: boolean; id?: string; nome?: string; observacoes?: string | null; razao_social?: string | null; rede_social?: string | null; segmento_id?: string | null; site?: string | null; telefone?: string | null; uf?: string | null; updated_at?: string };
        Relationships: [
          { foreignKeyName: "empresas_criado_por_fkey"; columns: ["criado_por"]; isOneToOne: false; referencedRelation: "membros"; referencedColumns: ["id"] },
          { foreignKeyName: "empresas_segmento_id_fkey"; columns: ["segmento_id"]; isOneToOne: false; referencedRelation: "segmentos"; referencedColumns: ["id"] },
        ];
      };
      fase_campos: {
        Row: { ajuda: string | null; chave: string; fase_id: string; id: string; obrigatorio: boolean; opcoes: Json | null; ordem: number; rotulo: string; tipo: Database["public"]["Enums"]["tipo_campo"] };
        Insert: { ajuda?: string | null; chave: string; fase_id: string; id?: string; obrigatorio?: boolean; opcoes?: Json | null; ordem?: number; rotulo: string; tipo?: Database["public"]["Enums"]["tipo_campo"] };
        Update: { ajuda?: string | null; chave?: string; fase_id?: string; id?: string; obrigatorio?: boolean; opcoes?: Json | null; ordem?: number; rotulo?: string; tipo?: Database["public"]["Enums"]["tipo_campo"] };
        Relationships: [
          { foreignKeyName: "fase_campos_fase_id_fkey"; columns: ["fase_id"]; isOneToOne: false; referencedRelation: "fases"; referencedColumns: ["id"] },
        ];
      };
      fases: {
        Row: { acao_sla: Database["public"]["Enums"]["acao_sla"] | null; ativa: boolean; auto_mover_para: string | null; chave: string; descricao: string | null; distribui_responsavel: boolean; exige_motivo: Database["public"]["Enums"]["tipo_motivo"] | null; fase_destino_sla: string | null; funil_id: string; id: string; macroetapa: Database["public"]["Enums"]["macroetapa"]; nome: string; ordem: number; probabilidade: number; sla_dias: number | null; tipo: Database["public"]["Enums"]["tipo_fase"] };
        Insert: { acao_sla?: Database["public"]["Enums"]["acao_sla"] | null; ativa?: boolean; auto_mover_para?: string | null; chave: string; descricao?: string | null; distribui_responsavel?: boolean; exige_motivo?: Database["public"]["Enums"]["tipo_motivo"] | null; fase_destino_sla?: string | null; funil_id: string; id?: string; macroetapa: Database["public"]["Enums"]["macroetapa"]; nome: string; ordem: number; probabilidade?: number; sla_dias?: number | null; tipo?: Database["public"]["Enums"]["tipo_fase"] };
        Update: { acao_sla?: Database["public"]["Enums"]["acao_sla"] | null; ativa?: boolean; auto_mover_para?: string | null; chave?: string; descricao?: string | null; distribui_responsavel?: boolean; exige_motivo?: Database["public"]["Enums"]["tipo_motivo"] | null; fase_destino_sla?: string | null; funil_id?: string; id?: string; macroetapa?: Database["public"]["Enums"]["macroetapa"]; nome?: string; ordem?: number; probabilidade?: number; sla_dias?: number | null; tipo?: Database["public"]["Enums"]["tipo_fase"] };
        Relationships: [
          { foreignKeyName: "fases_auto_mover_para_fkey"; columns: ["auto_mover_para"]; isOneToOne: false; referencedRelation: "fases"; referencedColumns: ["id"] },
          { foreignKeyName: "fases_fase_destino_sla_fkey"; columns: ["fase_destino_sla"]; isOneToOne: false; referencedRelation: "fases"; referencedColumns: ["id"] },
          { foreignKeyName: "fases_funil_id_fkey"; columns: ["funil_id"]; isOneToOne: false; referencedRelation: "funis"; referencedColumns: ["id"] },
        ];
      };
      funis: {
        Row: { chave: string; diretoria: string; id: string; nome: string };
        Insert: { chave: string; diretoria: string; id?: string; nome: string };
        Update: { chave?: string; diretoria?: string; id?: string; nome?: string };
        Relationships: [
          { foreignKeyName: "funis_diretoria_fkey"; columns: ["diretoria"]; isOneToOne: false; referencedRelation: "diretorias"; referencedColumns: ["slug"] },
        ];
      };
      membro_diretorias: {
        Row: { cargo: Database["public"]["Enums"]["cargo"]; created_at: string; diretoria: string; membro_id: string; participa_rodizio: boolean };
        Insert: { cargo: Database["public"]["Enums"]["cargo"]; created_at?: string; diretoria: string; membro_id: string; participa_rodizio?: boolean };
        Update: { cargo?: Database["public"]["Enums"]["cargo"]; created_at?: string; diretoria?: string; membro_id?: string; participa_rodizio?: boolean };
        Relationships: [
          { foreignKeyName: "membro_diretorias_diretoria_fkey"; columns: ["diretoria"]; isOneToOne: false; referencedRelation: "diretorias"; referencedColumns: ["slug"] },
          { foreignKeyName: "membro_diretorias_membro_id_fkey"; columns: ["membro_id"]; isOneToOne: false; referencedRelation: "membros"; referencedColumns: ["id"] },
        ];
      };
      membros: {
        Row: { ativo: boolean; avatar_url: string | null; created_at: string; email: string; id: string; nome: string; telefone: string | null; updated_at: string };
        Insert: { ativo?: boolean; avatar_url?: string | null; created_at?: string; email: string; id: string; nome: string; telefone?: string | null; updated_at?: string };
        Update: { ativo?: boolean; avatar_url?: string | null; created_at?: string; email?: string; id?: string; nome?: string; telefone?: string | null; updated_at?: string };
        Relationships: [];
      };
      metas: {
        Row: { alvo: number; codigo: string | null; created_at: string; diretoria: string; id: string; indicador: string | null; membro_id: string | null; objetivo: string; ordem: number; peso: number; realizado_manual: number | null; titulo: string; trimestre: string; unidade: string };
        Insert: { alvo: number; codigo?: string | null; created_at?: string; diretoria: string; id?: string; indicador?: string | null; membro_id?: string | null; objetivo: string; ordem?: number; peso?: number; realizado_manual?: number | null; titulo: string; trimestre: string; unidade?: string };
        Update: { alvo?: number; codigo?: string | null; created_at?: string; diretoria?: string; id?: string; indicador?: string | null; membro_id?: string | null; objetivo?: string; ordem?: number; peso?: number; realizado_manual?: number | null; titulo?: string; trimestre?: string; unidade?: string };
        Relationships: [
          { foreignKeyName: "metas_diretoria_fkey"; columns: ["diretoria"]; isOneToOne: false; referencedRelation: "diretorias"; referencedColumns: ["slug"] },
          { foreignKeyName: "metas_membro_id_fkey"; columns: ["membro_id"]; isOneToOne: false; referencedRelation: "membros"; referencedColumns: ["id"] },
        ];
      };
      motivos: {
        Row: { ativo: boolean; diretoria: string; id: string; nome: string; ordem: number; tipo: Database["public"]["Enums"]["tipo_motivo"] };
        Insert: { ativo?: boolean; diretoria?: string; id?: string; nome: string; ordem?: number; tipo: Database["public"]["Enums"]["tipo_motivo"] };
        Update: { ativo?: boolean; diretoria?: string; id?: string; nome?: string; ordem?: number; tipo?: Database["public"]["Enums"]["tipo_motivo"] };
        Relationships: [
          { foreignKeyName: "motivos_diretoria_fkey"; columns: ["diretoria"]; isOneToOne: false; referencedRelation: "diretorias"; referencedColumns: ["slug"] },
        ];
      };
      negocio_historico: {
        Row: { automatico: boolean; autor_id: string | null; comentario: string | null; created_at: string; fase_destino_id: string; fase_origem_id: string | null; id: number; motivo_id: string | null; negocio_id: string };
        Insert: { automatico?: boolean; autor_id?: string | null; comentario?: string | null; created_at?: string; fase_destino_id: string; fase_origem_id?: string | null; id?: never; motivo_id?: string | null; negocio_id: string };
        Update: { automatico?: boolean; autor_id?: string | null; comentario?: string | null; created_at?: string; fase_destino_id?: string; fase_origem_id?: string | null; id?: never; motivo_id?: string | null; negocio_id?: string };
        Relationships: [
          { foreignKeyName: "negocio_historico_autor_id_fkey"; columns: ["autor_id"]; isOneToOne: false; referencedRelation: "membros"; referencedColumns: ["id"] },
          { foreignKeyName: "negocio_historico_fase_destino_id_fkey"; columns: ["fase_destino_id"]; isOneToOne: false; referencedRelation: "fases"; referencedColumns: ["id"] },
          { foreignKeyName: "negocio_historico_fase_origem_id_fkey"; columns: ["fase_origem_id"]; isOneToOne: false; referencedRelation: "fases"; referencedColumns: ["id"] },
          { foreignKeyName: "negocio_historico_motivo_id_fkey"; columns: ["motivo_id"]; isOneToOne: false; referencedRelation: "motivos"; referencedColumns: ["id"] },
          { foreignKeyName: "negocio_historico_negocio_id_fkey"; columns: ["negocio_id"]; isOneToOne: false; referencedRelation: "negocios"; referencedColumns: ["id"] },
        ];
      };
      negocio_participantes: {
        Row: { membro_id: string; negocio_id: string; papel: string | null };
        Insert: { membro_id: string; negocio_id: string; papel?: string | null };
        Update: { membro_id?: string; negocio_id?: string; papel?: string | null };
        Relationships: [
          { foreignKeyName: "negocio_participantes_membro_id_fkey"; columns: ["membro_id"]; isOneToOne: false; referencedRelation: "membros"; referencedColumns: ["id"] },
          { foreignKeyName: "negocio_participantes_negocio_id_fkey"; columns: ["negocio_id"]; isOneToOne: false; referencedRelation: "negocios"; referencedColumns: ["id"] },
        ];
      };
      negocio_servicos: {
        Row: { negocio_id: string; servico_id: string };
        Insert: { negocio_id: string; servico_id: string };
        Update: { negocio_id?: string; servico_id?: string };
        Relationships: [
          { foreignKeyName: "negocio_servicos_negocio_id_fkey"; columns: ["negocio_id"]; isOneToOne: false; referencedRelation: "negocios"; referencedColumns: ["id"] },
          { foreignKeyName: "negocio_servicos_servico_id_fkey"; columns: ["servico_id"]; isOneToOne: false; referencedRelation: "servicos"; referencedColumns: ["id"] },
        ];
      };
      negocios: {
        Row: { campos: Json; contato_id: string | null; created_at: string; criado_por: string | null; data_coldcall_1: string | null; data_coldcall_2: string | null; dores_identificadas: string | null; empresa_id: string; encerrado_em: string | null; entrou_na_fase_em: string; fase_id: string; ficticio: boolean; funil_id: string; ganho_em: string | null; id: string; motivo_detalhe: string | null; motivo_id: string | null; origem_detalhe: string | null; origem_id: string | null; responsavel_id: string | null; retorno_em: string | null; titulo: string; updated_at: string; valor: number | null };
        Insert: { campos?: Json; contato_id?: string | null; created_at?: string; criado_por?: string | null; data_coldcall_1?: string | null; data_coldcall_2?: string | null; dores_identificadas?: string | null; empresa_id: string; encerrado_em?: string | null; entrou_na_fase_em?: string; fase_id: string; ficticio?: boolean; funil_id: string; ganho_em?: string | null; id?: string; motivo_detalhe?: string | null; motivo_id?: string | null; origem_detalhe?: string | null; origem_id?: string | null; responsavel_id?: string | null; retorno_em?: string | null; titulo: string; updated_at?: string; valor?: number | null };
        Update: { campos?: Json; contato_id?: string | null; created_at?: string; criado_por?: string | null; data_coldcall_1?: string | null; data_coldcall_2?: string | null; dores_identificadas?: string | null; empresa_id?: string; encerrado_em?: string | null; entrou_na_fase_em?: string; fase_id?: string; ficticio?: boolean; funil_id?: string; ganho_em?: string | null; id?: string; motivo_detalhe?: string | null; motivo_id?: string | null; origem_detalhe?: string | null; origem_id?: string | null; responsavel_id?: string | null; retorno_em?: string | null; titulo?: string; updated_at?: string; valor?: number | null };
        Relationships: [
          { foreignKeyName: "negocios_contato_id_fkey"; columns: ["contato_id"]; isOneToOne: false; referencedRelation: "contatos"; referencedColumns: ["id"] },
          { foreignKeyName: "negocios_criado_por_fkey"; columns: ["criado_por"]; isOneToOne: false; referencedRelation: "membros"; referencedColumns: ["id"] },
          { foreignKeyName: "negocios_empresa_id_fkey"; columns: ["empresa_id"]; isOneToOne: false; referencedRelation: "empresas"; referencedColumns: ["id"] },
          { foreignKeyName: "negocios_fase_id_fkey"; columns: ["fase_id"]; isOneToOne: false; referencedRelation: "fases"; referencedColumns: ["id"] },
          { foreignKeyName: "negocios_funil_id_fkey"; columns: ["funil_id"]; isOneToOne: false; referencedRelation: "funis"; referencedColumns: ["id"] },
          { foreignKeyName: "negocios_motivo_id_fkey"; columns: ["motivo_id"]; isOneToOne: false; referencedRelation: "motivos"; referencedColumns: ["id"] },
          { foreignKeyName: "negocios_origem_id_fkey"; columns: ["origem_id"]; isOneToOne: false; referencedRelation: "origens"; referencedColumns: ["id"] },
          { foreignKeyName: "negocios_responsavel_id_fkey"; columns: ["responsavel_id"]; isOneToOne: false; referencedRelation: "membros"; referencedColumns: ["id"] },
        ];
      };
      origens: {
        Row: { ativo: boolean; diretoria: string; id: string; nome: string; ordem: number };
        Insert: { ativo?: boolean; diretoria?: string; id?: string; nome: string; ordem?: number };
        Update: { ativo?: boolean; diretoria?: string; id?: string; nome?: string; ordem?: number };
        Relationships: [
          { foreignKeyName: "origens_diretoria_fkey"; columns: ["diretoria"]; isOneToOne: false; referencedRelation: "diretorias"; referencedColumns: ["slug"] },
        ];
      };
      pre_cadastro_diretorias: {
        Row: { cargo: Database["public"]["Enums"]["cargo"]; diretoria: string; pre_cadastro_id: string };
        Insert: { cargo: Database["public"]["Enums"]["cargo"]; diretoria: string; pre_cadastro_id: string };
        Update: { cargo?: Database["public"]["Enums"]["cargo"]; diretoria?: string; pre_cadastro_id?: string };
        Relationships: [
          { foreignKeyName: "pre_cadastro_diretorias_diretoria_fkey"; columns: ["diretoria"]; isOneToOne: false; referencedRelation: "diretorias"; referencedColumns: ["slug"] },
          { foreignKeyName: "pre_cadastro_diretorias_pre_cadastro_id_fkey"; columns: ["pre_cadastro_id"]; isOneToOne: false; referencedRelation: "pre_cadastros"; referencedColumns: ["id"] },
        ];
      };
      pre_cadastros: {
        Row: { aceito_em: string | null; convite_enviado_em: string | null; created_at: string; criado_por: string | null; email: string; id: string; nome: string };
        Insert: { aceito_em?: string | null; convite_enviado_em?: string | null; created_at?: string; criado_por?: string | null; email: string; id?: string; nome: string };
        Update: { aceito_em?: string | null; convite_enviado_em?: string | null; created_at?: string; criado_por?: string | null; email?: string; id?: string; nome?: string };
        Relationships: [
          { foreignKeyName: "pre_cadastros_criado_por_fkey"; columns: ["criado_por"]; isOneToOne: false; referencedRelation: "membros"; referencedColumns: ["id"] },
        ];
      };
      rodizio_estado: {
        Row: { atualizado_em: string; funil_id: string; ultimo_membro_id: string | null };
        Insert: { atualizado_em?: string; funil_id: string; ultimo_membro_id?: string | null };
        Update: { atualizado_em?: string; funil_id?: string; ultimo_membro_id?: string | null };
        Relationships: [
          { foreignKeyName: "rodizio_estado_funil_id_fkey"; columns: ["funil_id"]; isOneToOne: true; referencedRelation: "funis"; referencedColumns: ["id"] },
          { foreignKeyName: "rodizio_estado_ultimo_membro_id_fkey"; columns: ["ultimo_membro_id"]; isOneToOne: false; referencedRelation: "membros"; referencedColumns: ["id"] },
        ];
      };
      segmentos: {
        Row: { ativo: boolean; diretoria: string; id: string; nome: string };
        Insert: { ativo?: boolean; diretoria?: string; id?: string; nome: string };
        Update: { ativo?: boolean; diretoria?: string; id?: string; nome?: string };
        Relationships: [
          { foreignKeyName: "segmentos_diretoria_fkey"; columns: ["diretoria"]; isOneToOne: false; referencedRelation: "diretorias"; referencedColumns: ["slug"] },
        ];
      };
      servicos: {
        Row: { area: Database["public"]["Enums"]["area_servico"]; ativo: boolean; descricao: string | null; diretoria: string; id: string; nome: string; ordem: number };
        Insert: { area: Database["public"]["Enums"]["area_servico"]; ativo?: boolean; descricao?: string | null; diretoria?: string; id?: string; nome: string; ordem?: number };
        Update: { area?: Database["public"]["Enums"]["area_servico"]; ativo?: boolean; descricao?: string | null; diretoria?: string; id?: string; nome?: string; ordem?: number };
        Relationships: [
          { foreignKeyName: "servicos_diretoria_fkey"; columns: ["diretoria"]; isOneToOne: false; referencedRelation: "diretorias"; referencedColumns: ["slug"] },
        ];
      };
    };
    Views: { [_ in never]: never };
    Functions: {
      empresas_semelhantes: {
        Args: { _cnpj?: string; _dominio?: string; _nome: string; _telefone?: string };
        Returns: { cidade: string; cnpj: string; id: string; motivo: string; nome: string; semelhanca: number }[];
      };
      mover_negocio: {
        Args: { _comentario?: string; _fase: string; _motivo?: string; _motivo_detalhe?: string; _negocio: string; _retorno_em?: string };
        Returns: undefined;
      };
      normalizar: { Args: { _t: string }; Returns: string };
      so_digitos: { Args: { _t: string }; Returns: string };
    };
    Enums: {
      acao_sla: "alertar" | "mover";
      area_servico: "negocios" | "producao" | "qualidade";
      cargo: "diretor" | "assessor" | "trainee";
      macroetapa: "prospeccao" | "cadencia" | "oportunidade" | "venda" | "ganho" | "pausa" | "perda";
      tipo_campo: "texto" | "texto_longo" | "data" | "numero" | "moeda" | "membros" | "selecao" | "booleano" | "link";
      tipo_fase: "aberta" | "ganho" | "perda" | "pausa";
      tipo_motivo: "perda" | "desqualificacao";
    };
    CompositeTypes: { [_ in never]: never };
  };
};

// Atalhos usados no app
export type Tables<T extends keyof Database["public"]["Tables"]> = Database["public"]["Tables"][T]["Row"];
export type TablesInsert<T extends keyof Database["public"]["Tables"]> = Database["public"]["Tables"][T]["Insert"];
export type TablesUpdate<T extends keyof Database["public"]["Tables"]> = Database["public"]["Tables"][T]["Update"];
export type Enums<T extends keyof Database["public"]["Enums"]> = Database["public"]["Enums"][T];
