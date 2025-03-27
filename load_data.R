# -----------------------------
# 📚 Script: Load, Merge & Analyze Bibliographic Data with Biblioshiny
# -----------------------------
# Este script realiza as seguintes etapas:
# 1. Verifica se já existe uma base unificada (objeto M) salva em "data/processed/biblio_merged.RData".
#    - Se existir, carrega o objeto M existente.
#    - Caso contrário, carrega arquivos bibliográficos de diversas fontes (IEEE, PubMed, PsycNET, WOS, Scopus),
#      une as bases removendo duplicatas (priorizando DOI e, depois, Título),
#      atribui o resultado à variável M e salva a base unificada em CSV e RData.
# 2. Inicia a interface interativa do Biblioshiny para análise exploratória.
# -----------------------------

# 1. Instalação e carregamento dos pacotes necessários
necessary_packages <- c("bibliometrix", "dplyr", "readr")
for (pkg in necessary_packages) {
  if (!require(pkg, character.only = TRUE)) {
    install.packages(pkg, dependencies = TRUE)
    library(pkg, character.only = TRUE)
  }
}

# 2. Definir diretório e caminhos dos arquivos de saída
output_dir <- "data/processed"
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

csv_file <- file.path(output_dir, "biblio_merged.csv")
rdata_file <- file.path(output_dir, "biblio_merged.RData")

# 3. Verifica se a base unificada já existe para evitar sobrescrever dados
if (file.exists(rdata_file)) {
  message("O arquivo '", rdata_file, "' já existe. Carregando o objeto M existente...")
  load(rdata_file)  # Carrega a variável M no ambiente
} else {
  # 3.1 Função para carregar múltiplos arquivos de uma pasta com verificação de retorno
  load_multiple_files <- function(path, pattern, dbsource, file_format = "bibtex") {
    files <- list.files(path, pattern = pattern, full.names = TRUE)
    if (length(files) == 0) {
      warning("Nenhum arquivo encontrado em: ", path)
      return(NULL)
    }
    
    data_list <- lapply(files, function(file) {
      tryCatch({
        df <- convert2df(file = file, dbsource = dbsource, format = file_format)
        if (is.null(df) || nrow(df) == 0) {
          warning("O arquivo ", file, " não retornou dados e será ignorado.")
          return(NULL)
        } else {
          return(df)
        }
      }, error = function(e) {
        warning("Erro ao ler: ", file, "\n", e$message)
        return(NULL)
      })
    })
    
    # Remove elementos nulos e une os data frames
    bind_rows(Filter(Negate(is.null), data_list))
  }
  
  # 3.2 Carregar dados de cada fonte com mensagens informativas
  message("Carregando dados do IEEE...")
  ieee_data <- load_multiple_files("data/raw/IEEE", "\\.bib$", "isi")
  
  message("Carregando dados do PubMed...")
  pm_data <- tryCatch({
    df <- convert2df("data/raw/PM/pubmed1.nbib", dbsource = "pubmed", format = "pubmed")
    if (is.null(df) || nrow(df) == 0) {
      warning("O arquivo PubMed não retornou dados.")
      NULL
    } else {
      df
    }
  }, error = function(e) {
    warning("Erro ao ler o arquivo PubMed: ", e$message)
    NULL
  })
  
  message("Carregando dados do PsycNET (RIS)...")
  pn_data <- tryCatch({
    df <- convert2df("data/raw/PN/PsycNET1.ris", dbsource = "generic", format = "endnote")
    if (is.null(df) || nrow(df) == 0) {
      warning("O arquivo PsycNET não retornou dados.")
      NULL
    } else {
      df
    }
  }, error = function(e) {
    warning("Erro ao converter o arquivo PsycNET1.ris: ", e$message)
    NULL
  })
  
  message("Carregando dados do Web of Science...")
  wos_data <- load_multiple_files("data/raw/WOS", "\\.bib$", "wos")
  
  message("Carregando dados do Scopus...")
  scopus_data <- load_multiple_files("data/raw/SCOPUS", "\\.bib$", "scopus")
  
  # 3.3 Unir todas as bases que não estão vazias
  all_data <- list(ieee_data, pm_data, pn_data, wos_data, scopus_data)
  merged_data <- bind_rows(Filter(Negate(is.null), all_data))
  
  # 3.4 Remover duplicatas: primeiro por DOI (DI) e depois por Título (TI)
  merged_data <- merged_data %>%
    distinct(DI, .keep_all = TRUE) %>% 
    distinct(TI, .keep_all = TRUE)
  
  # 3.5 Atribuir o resultado final à variável M (necessária para o Biblioshiny)
  M <- merged_data
  
  # 3.6 Salvar a base unificada em CSV e RData (contendo o objeto M)
  write.csv(M, csv_file, row.names = FALSE)
  save(M, file = rdata_file)
  
  message("✅ Base bibliográfica unificada salva com sucesso:")
  message("   CSV: ", csv_file)
  message("   RData: ", rdata_file)
}

# 4. Iniciar a interface interativa do Biblioshiny
biblioshiny()