package com.walkingrpg.backend.platform.application;

import java.util.Set;

import com.walkingrpg.backend.platform.infrastructure.PlatformRepository;
import org.springframework.stereotype.Service;

@Service
public class RepositoryPlatformSkillAccess implements PlatformSkillAccess {

    private final PlatformRepository repository;

    public RepositoryPlatformSkillAccess(PlatformRepository repository) {
        this.repository = repository;
    }

    @Override
    public Set<String> unlockedSkills(String userId) {
        return repository.findUnlockedSkills(userId);
    }
}
