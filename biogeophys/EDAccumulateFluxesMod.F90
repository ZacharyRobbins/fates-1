module EDAccumulateFluxesMod

  !------------------------------------------------------------------------------
  ! !DESCRIPTION:
  ! This routine accumulates NPP, GPP and respiration of each cohort over the course of each 24 hour period. 
  ! The fluxes are stored per cohort, and the npp_tstep (etc) fluxes are calcualted in EDPhotosynthesis
  ! This routine cannot be in EDPhotosynthesis because EDPhotosynthesis is a loop and therefore would
  ! erroneously add these things up multiple times. 
  ! Rosie Fisher. March 2014. 
  !
  ! !USES:
  use FatesGlobals, only      : endrun => fates_endrun 
  use FatesGlobals, only      : fates_log
  use shr_log_mod , only      : errMsg => shr_log_errMsg
  use FatesConstantsMod , only : r8 => fates_r8


  implicit none
  private
  !
  public :: AccumulateFluxes_ED

  logical :: debug = .false.  ! for debugging this module

  character(len=*), parameter, private :: sourcefile = &
       __FILE__

contains

  !------------------------------------------------------------------------------

  subroutine AccumulateFluxes_ED(nsites, sites, bc_in, bc_out, dt_time)

    !
    ! !DESCRIPTION:
    ! see above
    !
    ! !USES:

    use EDTypesMod        , only : ed_patch_type, ed_cohort_type, &
         ed_site_type, AREA
    use FatesInterfaceTypesMod , only : bc_in_type,bc_out_type

    !
    ! !ARGUMENTS    
    integer,            intent(in)            :: nsites
    type(ed_site_type), intent(inout), target :: sites(nsites)
    type(bc_in_type),   intent(in)            :: bc_in(nsites)
    type(bc_out_type),  intent(inout)         :: bc_out(nsites)
    real(r8),           intent(in)            :: dt_time  ! timestep interval
    !
    ! !LOCAL VARIABLES:
    type(ed_cohort_type), pointer  :: ccohort ! current cohort
    type(ed_patch_type) , pointer  :: cpatch ! current patch
    integer :: iv !leaf layer
    integer :: c  ! clm/alm column
    integer :: s  ! ed site
    integer :: ifp ! index fates patch
    !----------------------------------------------------------------------

    do s = 1, nsites

       ifp = 0

       cpatch => sites(s)%oldest_patch
       do while (associated(cpatch))                 
          if(cpatch%nocomp_pft_label.ne.0)then
             ifp = ifp+1

             if( bc_in(s)%filter_photo_pa(ifp) == 3 ) then
                ccohort => cpatch%shortest
                do while(associated(ccohort))

                   ! Accumulate fluxes from hourly to daily values. 
                   ! _tstep fluxes are KgC/indiv/timestep _acc are KgC/indiv/day

                   if ( debug ) then

                      write(fates_log(),*) 'EDAccumFlux 64 ',ccohort%npp_tstep
                      write(fates_log(),*) 'EDAccumFlux 66 ',ccohort%gpp_tstep
                      write(fates_log(),*) 'EDAccumFlux 67 ',ccohort%resp_tstep

                   endif

                   ccohort%npp_acc  = ccohort%npp_acc  + ccohort%npp_tstep 
                   ccohort%gpp_acc  = ccohort%gpp_acc  + ccohort%gpp_tstep 
                   ccohort%resp_acc = ccohort%resp_acc + ccohort%resp_tstep

                   ! weighted mean of D13C by gpp
                   if((ccohort%gpp_acc + ccohort%gpp_tstep) .eq. 0.0_r8) then
                      ccohort%c13disc_acc = 0.0_r8
                   else
                      ccohort%c13disc_acc  = ((ccohort%c13disc_acc * ccohort%gpp_acc) + &
                           (ccohort%c13disc_clm * ccohort%gpp_tstep)) / &
                           (ccohort%gpp_acc + ccohort%gpp_tstep)
                   endif

                   do iv=1,ccohort%nv
                      if(ccohort%year_net_uptake(iv) == 999._r8)then ! note that there were leaves in this layer this year. 
                         ccohort%year_net_uptake(iv) = 0._r8
                      end if
                      ccohort%year_net_uptake(iv) = ccohort%year_net_uptake(iv) + ccohort%ts_net_uptake(iv)
                   enddo

                   ccohort => ccohort%taller
                enddo ! while(associated(ccohort))
             end if
          end if ! not bare ground
          cpatch => cpatch%younger
       end do  ! while(associated(cpatch))
    end do
    return

  end subroutine AccumulateFluxes_ED

end module EDAccumulateFluxesMod

