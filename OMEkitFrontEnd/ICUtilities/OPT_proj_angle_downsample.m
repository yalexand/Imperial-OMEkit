function [proj_ssd,angles] = OPT_proj_angle_downsample(full_filename,angle_index_step)

            omedata = bfopen(full_filename);

            r = loci.formats.ChannelFiller();
            r = loci.formats.ChannelSeparator(r);
            OMEXMLService = loci.formats.services.OMEXMLServiceImpl();
            r.setMetadataStore(OMEXMLService.createOMEXMLMetadata());
            r.setId(full_filename);
            r.setSeries(0);            
            omeMeta = r.getMetadataStore();             
                                                                    
            imgdata = omedata{1,1};                
            n_planes = length(imgdata(:,1));
                               
            proj = [];
                
                hw = waitbar(0,'..ehm..');
                for p = 1 : n_planes,                    
                    plane = imgdata{p,1};
                    %   
                    if isempty(proj)
                        [sizeX,sizeY] = size(plane);
                        proj = zeros(sizeX,sizeY,n_planes,class(plane));
                        %
                    end %  ini - end
                        %
                        proj(:,:,p) = plane;
                        %
                    if ~isempty(hw), waitbar(p/n_planes,hw); drawnow, end;                    
                    %
                end                                
                if ~isempty(hw), delete(hw), drawnow, end;

                modlo = r.getModuloZ();
                if ~isempty(modlo)
                     if ~isempty(modlo.labels)
                         ret = str2num(modlo.labels)';
                     end

                     if ~isempty(modlo.start)
                         if modlo.end > modlo.start
                            nsteps = round((modlo.end - modlo.start)/modlo.step);
                            ret = 0:nsteps;
                            ret = ret*modlo.step;
                            ret = ret + modlo.start;
                         end
                     end                     
                end
                vanilla_angles = ret;

range = 1:angle_index_step:n_planes;
angles = vanilla_angles(range);
proj_ssd = proj(:,:,range);

end


















                
                
                
                
                
                
                
                
                
                