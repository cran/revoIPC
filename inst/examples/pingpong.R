library(revoIPC)
library(nws)

pingpong_master <- function(semaphores, count=10) {
  sem0 <- semaphores$sem0
  sem1 <- semaphores$sem1
  for (i in seq(length=count)) {
    cat('calling post on sem0\n')
    ipcSemaphorePost(sem0)
    cat('calling wait on sem1\n')
    ipcSemaphoreWait(sem1)
    cat('Pong\n')
    Sys.sleep(1)
  }

  cat('cleaning up and exiting\n')
  ipcSemaphoreDestroy(sem0)
  ipcSemaphoreDestroy(sem1)
  invisible(NULL)
}

pingpong_worker <- function(name, count=10) {
  library(revoIPC)
  sem0name <- paste(name, '@0', sep='')
  sem1name <- paste(name, '@1', sep='')
  sem0 <- ipcSemaphoreOpen(sem0name)
  sem1 <- ipcSemaphoreOpen(sem1name)

  for (i in seq(length=count)) {
    ipcSemaphoreWait(sem0)
    cat('Ping\n')
    Sys.sleep(1)
    ipcSemaphorePost(sem1)
  }

  cat('cleaning up and exiting\n')
  ipcSemaphoreRelease(sem0)
  ipcSemaphoreRelease(sem1)
  invisible(NULL)
}

semaphoreGet <- function(sname) {
  tryCatch({
    ipcSemaphoreCreate(sname, 0)
  },
  error=function(e) {
    cat('failed to create semaphore: attempting to open\n')
    sem <- ipcSemaphoreOpen(sname)
    cat('destroying existing semaphore\n')
    ipcSemaphoreDestroy(sem)
    cat('creating new semaphore\n')
    ipcSemaphoreCreate(sname, 0)
  })
}

create_semaphores <- function(name) {
  sem0name <- paste(name, '@0', sep='')
  sem1name <- paste(name, '@1', sep='')
  sem0 <- semaphoreGet(sem0name)
  sem1 <- semaphoreGet(sem1name)
  list(sem0=sem0, sem1=sem1)
}

name <- 'foo'
pcount <- 10
sems <- create_semaphores(name)
s <- sleigh(launch='local', workerCount=4, verbose=TRUE, logDir='.')
cat('starting the workers\n')
sp <- eachWorker(s, pingpong_worker, name, count=pcount,
                 eo=list(blocking=FALSE))
cat('playing ping pong\n')
pingpong_master(sems, count=pcount * workerCount(s))
cat('waiting for workers to finish\n')
r <- waitSleigh(sp)
cat('finished\n')
close(s)
