#' Power Law Residual
#' 
#' Undertakes a power law residual analysis. This method compares
#' two time periods, however this function can take multiple time periods
#' and will complete all pairwise comparisons
#'
#' @param Data The data to be analysed. This should consist of rows of observations
#'        and columns indicating the species and location as well as either the year
#'        of the observation or columns specifying the start and end dates of the
#'        observation. This can be a dataframe object or a string giving the file path to
#'        a .csv or .rdata file. If left blank you will be prompted for a .csv or
#'        .rdata file.
#' @param time_periods This specifies the time periods to be analysed. A dataframe
#'        object with two columns. The first column contains the start year of each
#'        time period and the second column contains the end year of each time period. 
#' @param ignore.ireland If \code{TRUE} data from hectads in Ireland are removed.
#' @param ignore.channelislands If \code{TRUE} data from hectads in the Channel Islands
#'        are removed.
#' @param sinkdir An optional argument giving a file path where results should be written.
#'        This is useful if running the function in a loop over a number of datasets. Results
#'        are still returned to R when using \code{sinkdir}.
#' @param min_sq The minimum number of squares occupied in the first time period in
#'        order for a trend to be calculated for a species.
#' @param year_col The name of the year column in \code{Data}
#' @param site_col The name of the site column in \code{Data}
#' @param sp_col The name of the species column in \code{Data}
#' @param start_col The name of the start date column in \code{Data}
#' @param end_col The name of the end date column in \code{Data}
#' @return A dataframe of results are returned to R. The first column gives the names of 
#'         each species. Each subsequent column gives the result of a pairwise comparison
#'         between two time periods. The numbers in column headings indicate the time periods
#'         compared i.e. '1_2' indicates a comparison of the 1st and 2nd time periods '3_5'
#'         indicates a comparison of the 3rd and 5th time period. Time periods are ordered
#'         by their start year.
#' @keywords trends
#' @import reshape2
#' @examples
#' \dontrun{
#'  #load example dataset
#'  data(ex_dat)
#'  
#'  # Passing data as an R object
#'  plr_out <- plr(ex_dat,
#'                 time_periods=data.frame(start=c(1980,1990,2000),end=c(1989,1999,2009)),
#'                 site_col='hectad',
#'                 sp_col='CONCEPT',
#'                 start_col='TO_STARTDATE',
#'                 end_col='Date')
#' }

plr <- 
  function(Data=NULL,#your data (path to .csv or .rdata, or an R object)
           time_periods=NULL,
           ignore.ireland=F,#do you want to remove Irish hectads?
           ignore.channelislands=F, ##do you want to remove Channel Islands (they are not UK)?
           sinkdir=NULL,#where is the data going to be saved
           min_sq=5,
           year_col=NA,
           site_col=NA,
           sp_col=NA,
           start_col=NA,
           end_col=NA){
    
    # Clear warnings
    assign("last.warning", NULL, envir = baseenv())
    warn=FALSE
    if(is.na(site_col)){
      warning('Site column not specified')
      warn=TRUE
    }
    if(is.na(sp_col)){
      warning('Species column not specified')
      warn=TRUE
    }
    if(is.na(year_col)){
      if(is.na(start_col)|is.na(end_col)){
        warning('year_col or start_col and end_col must be given')
        warn=TRUE
      } 
    } else {
      if(!is.na(start_col)|!is.na(end_col)){
        warning('year_col cannot be used at the same time as start_col and end_col')
        warn=TRUE
      }
    }
    if(is.null(time_periods)){warning('time_periods must be given');warn=TRUE}
    if(!is.data.frame(Data)&length(Data)>1){warning('Data cannot have length > 1');warn=TRUE}
    if(warn) stop("Oops, you need to address these warnings")
    
    # ensure time_periods is ordered chronologically (this orders by the first column - start year)
    time_periods<-time_periods[with(time_periods, order(time_periods[,1])),]
    
    # Ensure reshape2 is installed
    required.packages <- c('reshape2')
    new.packages <- required.packages[!(required.packages %in% installed.packages()[,"Package"])]
    if(length(new.packages)) install.packages(new.packages)
    
    # If datafile is not given give dialog to locate file
    if(is.null(Data)){
      cat("Choose .csv or .rdata file. Else assign data.frame of data to 'data'")
      Data<-choose.files()
    } 
    
    analType<-'plr'
    
    if(!is.null(sinkdir)) dir.create(sinkdir,showWarnings = FALSE)
          
    print(paste('Starting',analType))
    datecode <- format(Sys.Date(),'%y%m%d')
    if(is.data.frame(Data)){
      taxa_data<-Data
      rm(Data)
    } else if(is.character(Data)&grepl('.rdata',Data,ignore.case=TRUE)){
      print('loading raw data')
      loaded<-load(Data)
      if(is.character(Data)&sum(grepl('taxa_data',loaded))==0){
        stop('The .rdata file used does not contain an object called "taxa_data"')
      }
    }else if(grepl('.csv',Data,ignore.case=TRUE)){
      print('loading raw data')
      taxa_data<-read.table(Data,header=TRUE,stringsAsFactors=FALSE,sep=',')
    }
    
    # Check column names
    new.colnames<-na.omit(c(site_col,sp_col,year_col,start_col,end_col))
    missingColNames<-new.colnames[!new.colnames %in% names(taxa_data)]
    if(length(missingColNames)>0) stop(paste(unlist(missingColNames),'is not the name of a column in data'))
    
    # Ensure date columns are dates
    if(!is.na(start_col)&!is.na(end_col)){      
      for( i in c(start_col,end_col)){
        if(!'POSIXct' %in% class(taxa_data[[i]]) & !'Date' %in% class(taxa_data[[i]])){
          warning(paste('column',i,'Date is not in a date format. This should be of class "Date" or "POSIXct", conversion attempted'))
          taxa_data[[i]]<-as.Date(taxa_data[[i]])
        }
      }
    }

    # We need to put each record into its time period
    if(!is.na(start_col) & !is.na(end_col)){
      for(ii in 1:length(time_periods[,1])){
        taxa_data$yearnew[as.numeric(format(taxa_data[start_col][[1]],'%Y'))>=time_periods[ii,1][[1]] &
                          as.numeric(format(taxa_data[end_col][[1]],'%Y'))<=time_periods[ii,2][[1]]]<-floor(rowMeans(time_periods[ii,])[[1]])
      }
    }else{
      for(ii in 1:length(time_periods[,1])){
        taxa_data$yearnew[taxa_data[year_col]>=time_periods[ii,1][[1]] &
                          taxa_data[year_col]<=time_periods[ii,2][[1]]]<-floor(rowMeans(time_periods[ii,])[[1]])
      }
    }
    
    taxa_data$year<-taxa_data$yearnew
    # Those that are not in these time periods are removed
    taxa_data<-taxa_data[!is.na(taxa_data$year),]
   
    #rename columns
    newnames<-c('hectad','CONCEPT')
    oldnames<-c(site_col,sp_col)
    taxa_data<-change_colnames(taxa_data,newnames,oldnames)
    
    # Ensure CONCEPT is a factor
    if(!is.na(sp_col))taxa_data$CONCEPT<-as.factor(taxa_data$CONCEPT)
    
    # Remove Ireland and Channel Islands if desired
    if(ignore.ireland) taxa_data <- subset(taxa_data, regexpr('^[A-Z]{2}', taxa_data[site_col])==1)
    if(ignore.channelislands) taxa_data <- subset(taxa_data, grepl('^[Ww][[:alpha:]]{1}', taxa_data[site_col])==FALSE)
  
    
    # For each pair of time periods go through and compare them
    # Compare the time periods
    for(ii in 1:(length(time_periods[,1])-1)){
      # to all other time periods
      for(j in (ii+1):length(time_periods[,1])){
        time_periods_temp<-time_periods[c(ii,j),] 
        taxon_temp<-paste(analType,'_',ii,'_',j,sep='')
        basic_temp<-basic_trends(taxa_data,time_periods_temp,min_sq=min_sq,
                                 run_telfer=FALSE,run_pd=FALSE)
        basic_temp<-as.data.frame(basic_temp$plr)
        colnames(basic_temp)<-paste(analType,'_',ii,'_',j,sep='')
        basic_temp$CONCEPT<-row.names(basic_temp)
        print(paste('Basic trends for tp',ii,'vs tp',j,'done',sep=' '))
        if(exists('basic_master')){
          basic_master<-merge(basic_master,basic_temp,by='CONCEPT',all=TRUE)
        }else{
          basic_master<-basic_temp
        }
      }
    }
    basic_master<-merge(basic_master,unique(taxa_data[c('CONCEPT')]),by='CONCEPT',all=TRUE)
    
    basic_master<-change_colnames(basic_master,sp_col,'CONCEPT')
    
    # If a sink directory is given write the output to file
    if(!is.null(sinkdir)){  
      file_name<-paste('Basic_trends_',analType,'_',datecode,'.csv',sep='')
      orgwd<-getwd()
      setwd(sinkdir)      
      if (file.exists(file_name)){
        file_name<-paste('Basic_trends_',analType,'_',datecode,'_',format(Sys.time(),'%H%M'),'.csv',sep='')
        warning(paste('Basic_trends_',analType,'_',datecode,'.csv',' already exists.',
                      ' The new data is saved with the time appended to the file name',sep=''),call.=FALSE,immediate.=TRUE)
      }
      write.csv(basic_master,file_name,row.names=FALSE)
      setwd(orgwd)
    }
    
    return(basic_master)
    
  }