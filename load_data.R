# -----------------------------
# 📚 Script: Load & Merge Bibliographic Data
# -----------------------------

# Instalar e carregar pacotes necessários
if (!require("bibliometrix")) install.packages("bibliometrix")
if (!require("dplyr")) install.packages("dplyr")
if (!require("readr")) install.packages("readr")

library(bibliometrix)
library(dplyr)

# Função genérica para carregar múltiplos arquivos de uma pasta
load_multiple_files <- function(path, pattern, dbsource, file_format = "bibtex") {
  files <- list.files(path, pattern = pattern, full.names = TRUE)
  if (length(files) == 0) return(NULL)
  
  data_list <- lapply(files, function(file) {
    tryCatch({
      convert2df(file = file, dbsource = dbsource, format = file_format)
    }, error = function(e) {
      warning(paste("Erro ao ler:", file))
      NULL
    })
  })
  
  bind_rows(data_list)
}

# Carregar dados de cada base
ieee_data   <- load_multiple_files("data/raw/IEEE", "\\.bib$", "isi")
pm_data     <- convert2df("data/raw/PM/pubmed1.nbib", dbsource = "pubmed", format = "nbib")
pn_data     <- convert2df("data/raw/PN/PsycNET1.ris", dbsource = "psyinfo", format = "ris")
wos_data    <- load_multiple_files("data/raw/WOS", "\\.bib$", "wos")
scopus_data <- load_multiple_files("data/raw/SCOPUS", "\\.bib$", "scopus")

# Unir todas as bases que não estão vazias
all_data <- list(ieee_data, pm_data, pn_data, wos_data, scopus_data)
merged_data <- bind_rows(Filter(Negate(is.null), all_data))

# Remover duplicatas (prioridade: DOI > Título)
merged_data <- merged_data %>%
  distinct(DI, .keep_all = TRUE) %>% 
  distinct(TI, .keep_all = TRUE)

# Criar pasta de saída, se não existir
if (!dir.exists("data/processed")) dir.create("data/processed", recursive = TRUE)

# Salvar base final
write.csv(merged_data, "data/processed/biblio_merged.csv", row.names = FALSE)
# save(merged_data, file = "data/processed/biblio_merged.RData") # opcional

# 📢 Iniciar biblioshiny (opcional)
# biblioshiny()

message("✅ Base bibliográfica unificada salva com sucesso!")